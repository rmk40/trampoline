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

    /// Forwards the given file URLs to their resolved editors.
    /// Per-extension overrides may route different files to different editors.
    /// URLs with no resolved editor are appended to `pendingFiles`.
    func forward(urls: [URL]) -> ForwardResult {
        let config = ConfigStore.shared

        // Group URLs by resolved editor
        var groups: [String: (editorURL: URL, urls: [URL])] = [:]
        var noEditorURLs: [URL] = []

        for url in urls {
            let ext = url.pathExtension
            guard let resolved = config.resolvedEditor(for: ext) else {
                noEditorURLs.append(url)
                continue
            }
            guard let editorURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: resolved.bundleID
            ) else {
                noEditorURLs.append(url)
                continue
            }
            var group = groups[resolved.bundleID] ?? (editorURL, [])
            group.urls.append(url)
            groups[resolved.bundleID] = group
        }

        // Queue files with no resolved editor
        if !noEditorURLs.isEmpty {
            pendingFiles.append(contentsOf: noEditorURLs)
        }

        // No editors resolved at all
        if groups.isEmpty {
            if config.editorBundleID == nil {
                return .noEditor
            } else {
                return .editorNotFound
            }
        }

        // Open each group in its respective editor
        for (bundleID, group) in groups {
            Task {
                do {
                    let openConfig = NSWorkspace.OpenConfiguration()
                    _ = try await NSWorkspace.shared.open(
                        group.urls,
                        withApplicationAt: group.editorURL,
                        configuration: openConfig)
                } catch {
                    NSLog("Trampoline: failed to open files with %@: %@",
                          bundleID, error.localizedDescription)
                }
            }
        }

        // If some files had no editor, surface it to the caller
        if !noEditorURLs.isEmpty {
            return config.editorBundleID == nil ? .noEditor : .editorNotFound
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
