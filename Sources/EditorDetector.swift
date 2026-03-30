import AppKit

// MARK: - Editor info

struct EditorInfo: Identifiable {
    var id: String { bundleID }
    let bundleID: String
    let displayName: String
    let shorthand: String?  // nil for dynamically discovered
    let appURL: URL
    let icon: NSImage
}

// MARK: - Detector

/// Scans the system for installed code editors from `EditorShorthands.all`.
/// Filters out Trampoline itself so it never appears as a target editor.
enum EditorDetector {

    static func detectInstalledEditors() -> [EditorInfo] {
        let workspace = NSWorkspace.shared

        return EditorShorthands.all.compactMap { entry in
            // Skip Trampoline itself
            guard entry.bundleID != ExtensionRegistry.trampolineBundleID else {
                return nil
            }

            guard let appURL = workspace.urlForApplication(
                withBundleIdentifier: entry.bundleID
            ) else {
                return nil
            }

            let icon = workspace.icon(forFile: appURL.path(percentEncoded: false))
            icon.size = NSSize(width: 32, height: 32)

            return EditorInfo(
                bundleID: entry.bundleID,
                displayName: entry.displayName,
                shorthand: entry.shorthand,
                appURL: appURL,
                icon: icon
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
