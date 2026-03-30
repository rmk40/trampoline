import Foundation

// MARK: - Editor entry

struct EditorEntry {
    let shorthand: String
    let bundleID: String
    let displayName: String
}

// MARK: - Registry

/// Single source of truth for known code editors.
/// All code paths (CLI, GUI, FileForwarder) must use this registry —
/// never hardcode an editor bundle ID elsewhere.
enum EditorShorthands {

    static let all: [EditorEntry] = [
        EditorEntry(shorthand: "zed",             bundleID: "dev.zed.Zed",                   displayName: "Zed"),
        EditorEntry(shorthand: "vscode",          bundleID: "com.microsoft.VSCode",           displayName: "Visual Studio Code"),
        EditorEntry(shorthand: "vscode-insiders",  bundleID: "com.microsoft.VSCodeInsiders",   displayName: "VS Code Insiders"),
        EditorEntry(shorthand: "cursor",          bundleID: "com.todesktop.230313mzl4w4u92",  displayName: "Cursor"),
        EditorEntry(shorthand: "sublime",         bundleID: "com.sublimetext.4",              displayName: "Sublime Text"),
        EditorEntry(shorthand: "sublime3",        bundleID: "com.sublimetext.3",              displayName: "Sublime Text 3"),
        EditorEntry(shorthand: "nova",            bundleID: "com.panic.Nova",                 displayName: "Nova"),
        EditorEntry(shorthand: "bbedit",          bundleID: "com.barebones.bbedit",           displayName: "BBEdit"),
        EditorEntry(shorthand: "textmate",        bundleID: "com.macromates.TextMate",        displayName: "TextMate"),
        EditorEntry(shorthand: "webstorm",        bundleID: "com.jetbrains.WebStorm",         displayName: "WebStorm"),
        EditorEntry(shorthand: "intellij",        bundleID: "com.jetbrains.intellij",         displayName: "IntelliJ IDEA"),
        EditorEntry(shorthand: "fleet",           bundleID: "com.jetbrains.fleet",            displayName: "Fleet"),
    ]

    // MARK: - Lookup

    /// Resolve an editor by shorthand (case-insensitive), then bundle ID
    /// (exact), then display name (case-insensitive). Returns nil if no match.
    static func resolve(_ input: String) -> EditorEntry? {
        let lower = input.lowercased()

        // 1. Shorthand (case-insensitive)
        if let entry = all.first(where: { $0.shorthand.lowercased() == lower }) {
            return entry
        }

        // 2. Bundle ID (exact match)
        if let entry = all.first(where: { $0.bundleID == input }) {
            return entry
        }

        // 3. Display name (case-insensitive)
        if let entry = all.first(where: { $0.displayName.lowercased() == lower }) {
            return entry
        }

        return nil
    }

    /// True if the bundle ID is in the registry or belongs to the JetBrains family.
    static func isKnownEditor(_ bundleID: String) -> Bool {
        if all.contains(where: { $0.bundleID == bundleID }) {
            return true
        }
        return bundleID.hasPrefix("com.jetbrains.")
    }
}
