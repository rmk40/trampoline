import Foundation

/// Single source of truth for all Trampoline configuration.
/// Both GUI and CLI bind to this store — never create parallel config mechanisms.
@Observable
final class ConfigStore {

    static let shared = ConfigStore()

    // MARK: - Defaults instance

    @ObservationIgnored
    let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            "showMenuBarIcon":   true,
            "firstRunComplete":  false,
            "claimedExtensions": [String](),
        ])
        // Read initial values from UserDefaults.
        // didSet does NOT fire during init, so no double-writing occurs.
        self.editorBundleID    = defaults.string(forKey: "editorBundleID")
        self.editorDisplayName = defaults.string(forKey: "editorDisplayName")
        self.showMenuBarIcon   = defaults.bool(forKey: "showMenuBarIcon")
        self.firstRunComplete  = defaults.bool(forKey: "firstRunComplete")
        self.claimedExtensions = defaults.stringArray(forKey: "claimedExtensions") ?? []
        self.editorOverrides = defaults.dictionary(forKey: "editorOverrides")
            as? [String: String] ?? [:]
        self.editorOverrideNames = defaults.dictionary(forKey: "editorOverrideNames")
            as? [String: String] ?? [:]
    }

    // MARK: - Persisted properties

    var editorBundleID: String? {
        didSet { defaults.set(editorBundleID, forKey: "editorBundleID") }
    }

    var editorDisplayName: String? {
        didSet { defaults.set(editorDisplayName, forKey: "editorDisplayName") }
    }

    var showMenuBarIcon: Bool = true {
        didSet { defaults.set(showMenuBarIcon, forKey: "showMenuBarIcon") }
    }

    var firstRunComplete: Bool = false {
        didSet { defaults.set(firstRunComplete, forKey: "firstRunComplete") }
    }

    var claimedExtensions: [String] = [] {
        didSet { defaults.set(claimedExtensions, forKey: "claimedExtensions") }
    }

    /// Per-extension editor overrides.
    /// Keys are lowercased file extensions without dot (e.g., "py", "kt").
    /// Values are editor bundle IDs.
    /// Only extensions with explicit overrides appear here.
    /// Extensions not in this dict use the global editorBundleID.
    var editorOverrides: [String: String] = [:] {
        didSet { defaults.set(editorOverrides, forKey: "editorOverrides") }
    }

    /// Display name cache for overridden editors: [bundleID: displayName].
    var editorOverrideNames: [String: String] = [:] {
        didSet { defaults.set(editorOverrideNames, forKey: "editorOverrideNames") }
    }

    // MARK: - Transient state (not persisted to UserDefaults)

    /// Warning message shown in GeneralTab (e.g. "Choose an editor…").
    /// Stored here so SwiftUI can observe changes via @Observable.
    var warningMessage: String?

    // MARK: - Editor resolution

    /// Resolves the editor for a given file extension.
    /// Extension override takes priority over the global default.
    func resolvedEditor(for ext: String) -> (bundleID: String, displayName: String)? {
        let lowered = ext.lowercased()
        if let overrideBundleID = editorOverrides[lowered] {
            let name = editorOverrideNames[overrideBundleID]
                ?? overrideBundleID
            return (overrideBundleID, name)
        }
        guard let id = editorBundleID, let name = editorDisplayName else {
            return nil
        }
        return (id, name)
    }

    /// Sets the editor override for multiple extensions at once.
    func setOverride(for exts: [String], editorBundleID: String, displayName: String) {
        var overrides = editorOverrides
        var names = editorOverrideNames
        for ext in exts { overrides[ext.lowercased()] = editorBundleID }
        names[editorBundleID] = displayName
        editorOverrides = overrides
        editorOverrideNames = names
    }

    /// Clears editor overrides for multiple extensions (reverts to default).
    func clearOverrides(for exts: [String]) {
        var overrides = editorOverrides
        for ext in exts { overrides.removeValue(forKey: ext.lowercased()) }
        editorOverrides = overrides
        // Prune names for editors no longer referenced by any override
        let usedBundleIDs = Set(editorOverrides.values)
        var names = editorOverrideNames
        for key in names.keys where !usedBundleIDs.contains(key) {
            names.removeValue(forKey: key)
        }
        editorOverrideNames = names
    }
}
