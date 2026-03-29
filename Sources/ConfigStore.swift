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
}
