import AppKit

/// Receives file URLs and forwards them to the user's configured editor.
final class FileForwarder {

    static let shared = FileForwarder()

    private init() {}

    // MARK: - Result type

    enum ForwardResult {
        case success
        case noEditor          // editorBundleID is nil
        case editorNotFound    // editor app not installed
    }

    // MARK: - Pending files

    /// Files that could not be forwarded (no editor configured or editor missing).
    private(set) var pendingFiles: [URL] = []

    // MARK: - Forward

    /// Forwards the given file URLs to the configured editor.
    /// On `.noEditor` or `.editorNotFound`, appends URLs to `pendingFiles`.
    func forward(urls: [URL]) -> ForwardResult {
        guard let bundleID = ConfigStore.shared.editorBundleID else {
            pendingFiles.append(contentsOf: urls)
            return .noEditor
        }

        guard let editorURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleID
        ) else {
            pendingFiles.append(contentsOf: urls)
            return .editorNotFound
        }

        let config = NSWorkspace.OpenConfiguration()

        // NSWorkspace.open is async — fire in a Task so we don't block the
        // main thread. Errors are logged; the synchronous return value reflects
        // whether we were *able* to attempt the open (editor resolved).
        Task {
            do {
                _ = try await NSWorkspace.shared.open(
                    urls,
                    withApplicationAt: editorURL,
                    configuration: config
                )
            } catch {
                NSLog("Trampoline: failed to open files with %@: %@",
                      bundleID, error.localizedDescription)
            }
        }

        return .success
    }

    // MARK: - Retry

    /// Re-forwards any files that were queued because the editor was
    /// unavailable. Clears `pendingFiles` before forwarding to prevent
    /// duplication — if `forward` fails, it re-appends them itself.
    func retryPending() -> ForwardResult {
        guard !pendingFiles.isEmpty else { return .success }

        let urls = pendingFiles
        pendingFiles = []  // clear BEFORE forward to prevent doubling
        return forward(urls: urls)
    }
}
