import AppKit
import Foundation

/// Parses `CommandLine.arguments` and dispatches CLI subcommands.
/// No external arg-parsing library — pure Foundation.
enum CLIHandler {

    // MARK: - Constants

    static let subcommands: Set<String> = [
        "editor", "extensions", "status", "claim", "release", "install-cli",
        "uninstall", "--help", "--version", "-h", "-v",
    ]

    // MARK: - Exit codes

    private static let exitSuccess: Int32 = 0
    private static let exitError: Int32   = 1
    private static let exitUsage: Int32   = 2

    // MARK: - Entry point

    /// Parse args and dispatch. Calls `exit()` when done.
    static func run() {
        let args = CommandLine.arguments
        guard args.count > 1 else {
            printUsage()
            exit(exitUsage)
        }

        let command = args[1]
        let rest = Array(args.dropFirst(2))

        switch command {
        case "editor":     handleEditor(rest)
        case "extensions": handleExtensions(rest)
        case "status":     handleStatus(rest)
        case "claim":      handleClaim(rest)
        case "release":   handleRelease(rest)
        case "install-cli": handleInstallCLI()
        case "uninstall": handleUninstall()
        case "--help", "-h":    printUsage(); exit(exitSuccess)
        case "--version", "-v":
            print("Trampoline \(ExtensionRegistry.version)")
            exit(exitSuccess)
        default:
            printErr("Unknown command: \(command)")
            printUsage()
            exit(exitUsage)
        }
    }

    // MARK: - editor

    private static func handleEditor(_ args: [String]) {
        let store = ConfigStore.shared

        // No argument → show current editor
        guard let input = args.first else {
            if let id = store.editorBundleID,
               let name = store.editorDisplayName {
                print("\(id) (\(name))")
            } else if let id = store.editorBundleID {
                print(id)
            } else {
                print("No editor configured.")
            }
            exit(exitSuccess)
        }

        // Extension-scoped commands: --list or first arg starts with "."
        if input == "--list" {
            handleEditorList()
        } else if input.hasPrefix(".") {
            handleEditorExtension(args)
        } else {
            // Global editor commands (unchanged)
            handleEditorGlobal(input)
        }
    }

    // MARK: - editor (global)

    /// Set the global default editor by shorthand, display name, or bundle ID.
    private static func handleEditorGlobal(_ input: String) {
        let store = ConfigStore.shared

        guard let resolved = resolveEditorInput(input) else {
            printErr("Unknown editor: \(input)")
            printErr("Use a shorthand (e.g., zed, vscode) or a bundle ID (e.g., com.microsoft.VSCode)")
            exit(exitError)
        }

        store.editorBundleID = resolved.bundleID
        store.editorDisplayName = resolved.displayName
        print("Default editor set to: \(resolved.displayName) (\(resolved.bundleID))")
        exit(exitSuccess)
    }

    // MARK: - editor --list

    /// Show global default and all per-extension overrides.
    private static func handleEditorList() {
        let store = ConfigStore.shared

        // Global default
        if let name = store.editorDisplayName, let id = store.editorBundleID {
            print("DEFAULT: \(name) (\(id))")
        } else if let id = store.editorBundleID {
            print("DEFAULT: \(id)")
        } else {
            print("DEFAULT: (none)")
        }

        let overrides = store.editorOverrides
        guard !overrides.isEmpty else {
            print()
            print("No per-extension overrides configured.")
            exit(exitSuccess)
        }

        // Group extensions by target bundle ID
        var grouped: [String: [String]] = [:]
        for (ext, bundleID) in overrides {
            grouped[bundleID, default: []].append(ext)
        }
        // Sort groups by first extension for stable output
        let sortedGroups = grouped.sorted { a, b in
            (a.value.sorted().first ?? "") < (b.value.sorted().first ?? "")
        }

        print()
        let totalExts = overrides.count
        print("OVERRIDES (\(totalExts)):")

        // Find max width of extension column for alignment
        let extStrings = sortedGroups.map { (_, exts) in
            exts.sorted().map { ".\($0)" }.joined(separator: " ")
        }
        let maxExtWidth = extStrings.map(\.count).max() ?? 0

        for (i, (bundleID, _)) in sortedGroups.enumerated() {
            let extStr = extStrings[i]
            let displayName = store.editorOverrideNames[bundleID] ?? bundleID
            let padded = extStr.padding(
                toLength: maxExtWidth, withPad: " ", startingAt: 0)
            print("  \(padded)  ->  \(displayName)")
        }

        exit(exitSuccess)
    }

    // MARK: - editor .ext [action]

    /// Handle extension-scoped editor commands: query, set, or clear.
    private static func handleEditorExtension(_ args: [String]) {
        let store = ConfigStore.shared

        // Parse comma-separated extensions from first arg
        let rawExts = args[0].split(separator: ",").map(String.init)
        let exts = rawExts.map { $0.hasPrefix(".") ? String($0.dropFirst()) : $0 }
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }

        guard !exts.isEmpty else {
            printErr("No valid extensions provided.")
            exit(exitError)
        }

        let dotExts = exts.map { ".\($0)" }

        // No second arg → query resolved editor for each extension
        guard args.count > 1 else {
            for ext in exts {
                let dotExt = ".\(ext)"
                if let resolved = store.resolvedEditor(for: ext) {
                    let isOverride = store.editorOverrides[ext.lowercased()] != nil
                    let tag = isOverride ? "override" : "default"
                    print("\(dotExt): \(resolved.bundleID) (\(resolved.displayName)) [\(tag)]")
                } else {
                    print("\(dotExt): (no editor configured)")
                }
            }
            exit(exitSuccess)
        }

        let action = args[1]

        // --clear → remove overrides
        if action == "--clear" {
            store.clearOverrides(for: exts)
            let defaultName = store.editorDisplayName ?? store.editorBundleID ?? "none"
            print("Cleared editor override for \(dotExts.joined(separator: ", ")) " +
                  "(will use default: \(defaultName))")
            exit(exitSuccess)
        }

        // Otherwise, treat action as editor shorthand / bundle ID
        let editorInput = args.dropFirst().joined(separator: " ")

        guard let resolved = resolveEditorInput(editorInput) else {
            printErr("Unknown editor: \(editorInput)")
            printErr("Use a shorthand (e.g., zed, vscode) or a bundle ID (e.g., com.microsoft.VSCode)")
            exit(exitError)
        }

        store.setOverride(for: exts, editorBundleID: resolved.bundleID,
                          displayName: resolved.displayName)
        print("Editor for \(dotExts.joined(separator: ", ")) set to: " +
              "\(resolved.displayName) (\(resolved.bundleID))")
        exit(exitSuccess)
    }

    // MARK: - extensions

    private static func handleExtensions(_ args: [String]) {
        guard let action = args.first, action != "--help" else {
            printExtensionsUsage()
            exit(args.isEmpty ? exitUsage : exitSuccess)
        }

        switch action {
        case "add":    handleExtensionsAdd(Array(args.dropFirst()))
        case "remove": handleExtensionsRemove(Array(args.dropFirst()))
        case "list":   handleExtensionsList()
        case "clear":  handleExtensionsClear()
        default:
            printErr("Unknown extensions action: \(action)")
            printExtensionsUsage()
            exit(exitUsage)
        }
    }

    private static func handleExtensionsAdd(_ args: [String]) {
        let input = args.joined(separator: " ")
        let parsed = ConfigStore.parseExtensionInput(input)
        guard !parsed.isEmpty else {
            printErr("No extensions provided.")
            printErr("Usage: trampoline extensions add .ext1 .ext2 ...")
            exit(exitError)
        }

        let store = ConfigStore.shared
        let existingCustom = Set(store.customExtensions)

        var addedCount = 0
        var alreadyCustomCount = 0
        var alreadyManagedCount = 0

        // Classify each extension before adding
        var toAdd = [String]()
        for ext in parsed {
            if ExtensionRegistry.managedExtension(for: ext) != nil {
                print("  Already managed: .\(ext)")
                alreadyManagedCount += 1
            } else if existingCustom.contains(ext) {
                print("  Already custom: .\(ext)")
                alreadyCustomCount += 1
            } else {
                toAdd.append(ext)
            }
        }

        if !toAdd.isEmpty {
            store.addCustomExtensions(toAdd)
            for ext in toAdd {
                print("  Added: .\(ext)")
                addedCount += 1
            }
        }

        print()
        print("\(addedCount) added, \(alreadyCustomCount) already custom, " +
              "\(alreadyManagedCount) already managed")
        exit(exitSuccess)
    }

    private static func handleExtensionsRemove(_ args: [String]) {
        let input = args.joined(separator: " ")
        let parsed = ConfigStore.parseExtensionInput(input)
        guard !parsed.isEmpty else {
            printErr("No extensions provided.")
            printErr("Usage: trampoline extensions remove .ext1 .ext2 ...")
            exit(exitError)
        }

        let store = ConfigStore.shared
        let existingCustom = Set(store.customExtensions)

        var toRemove = [String]()
        for ext in parsed {
            if existingCustom.contains(ext) {
                toRemove.append(ext)
                print("  Removed: .\(ext)")
            } else {
                print("  Not custom: .\(ext)")
            }
        }

        if !toRemove.isEmpty {
            store.removeCustomExtensions(toRemove)
        }

        exit(exitSuccess)
    }

    private static func handleExtensionsList() {
        let custom = ConfigStore.shared.customExtensions
        if custom.isEmpty {
            print("(none)")
        } else {
            for ext in custom {
                print(".\(ext)")
            }
        }
        exit(exitSuccess)
    }

    private static func handleExtensionsClear() {
        let store = ConfigStore.shared
        let count = store.customExtensions.count
        store.removeCustomExtensions(store.customExtensions)
        print("Cleared \(count) custom extension(s).")
        exit(exitSuccess)
    }

    private static func printExtensionsUsage() {
        let usage = """
        Manage custom file extensions.

        USAGE:
            trampoline extensions <action> [extensions]

        ACTIONS:
            add <exts>     Add custom extensions (e.g., .ext1 .ext2)
            remove <exts>  Remove custom extensions
            list           List all custom extensions
            clear          Remove all custom extensions

        EXAMPLES:
            trampoline extensions add .typ .roc .gleam
            trampoline extensions add typ,roc,gleam
            trampoline extensions remove .typ
            trampoline extensions list
            trampoline extensions clear
        """
        print(usage)
    }

    // MARK: - status

    private static func handleStatus(_ args: [String]) {
        let isJSON = args.contains("--json")
        let statuses = ExtensionRegistry.queryAllStatuses()

        if isJSON {
            printStatusJSON(statuses)
        } else {
            printStatusTable(statuses)
        }
        exit(exitSuccess)
    }

    private static func printStatusJSON(
        _ statuses: [(ext: String, status: HandlerStatus)]
    ) {
        let store = ConfigStore.shared
        let entries: [[String: Any]] = statuses.map { s in
            var dict: [String: Any] = ["ext": s.ext]
            switch s.status {
            case .registered:
                dict["status"] = "registered"
                dict["handler"] = ExtensionRegistry.trampolineBundleID
            case .claimed:
                dict["status"] = "claimed"
                dict["handler"] = ExtensionRegistry.trampolineBundleID
            case .other(let bundleID, let displayName):
                dict["status"] = "other"
                dict["handler"] = bundleID
                dict["handler_name"] = displayName
            case .unclaimed:
                dict["status"] = "unclaimed"
            }
            // Per-extension editor resolution
            let ext = s.ext
            if let resolved = store.resolvedEditor(for: ext) {
                dict["editor"] = resolved.bundleID
            }
            dict["editorOverride"] = store.editorOverrides[ext.lowercased()] != nil
            dict["custom"] = ExtensionRegistry.managedExtension(for: ext) == nil
            return dict
        }
        do {
            let data = try JSONSerialization.data(
                withJSONObject: entries,
                options: [.prettyPrinted, .sortedKeys])
            print(String(data: data, encoding: .utf8) ?? "[]")
        } catch {
            printErr("JSON serialization failed: \(error.localizedDescription)")
            print("[]")
        }
    }

    private static func printStatusTable(
        _ statuses: [(ext: String, status: HandlerStatus)]
    ) {
        let store = ConfigStore.shared

        // Header
        print("Trampoline v\(ExtensionRegistry.version)")
        if let name = store.editorDisplayName, let id = store.editorBundleID {
            print("Editor: \(name) (\(id))")
        } else if let id = store.editorBundleID {
            print("Editor: \(id)")
        } else {
            print("Editor: (none)")
        }
        print()

        // Group by status
        var registered = [String]()
        var claimed    = [String]()
        var other      = [(ext: String, handler: String)]()
        var unclaimed  = [String]()

        for s in statuses {
            switch s.status {
            case .registered:          registered.append(s.ext)
            case .claimed:             claimed.append(s.ext)
            case .other(_, let name):  other.append((s.ext, name))
            case .unclaimed:           unclaimed.append(s.ext)
            }
        }

        // REGISTERED
        print("REGISTERED (\(registered.count))" +
              " \u{2014} automatic via Info.plist")
        if registered.isEmpty {
            print("  (none)")
        } else {
            print("  \(registered.map { ".\($0)" }.joined(separator: " "))")
        }
        print()

        // CLAIMED
        print("CLAIMED (\(claimed.count))")
        if claimed.isEmpty {
            print("  (none)")
        } else {
            print("  \(claimed.map { ".\($0)" }.joined(separator: " "))")
        }
        print()

        // OTHER
        print("OTHER (\(other.count))")
        if other.isEmpty {
            print("  (none)")
        } else {
            let maxLen = other.map(\.ext.count).max() ?? 0
            for o in other {
                let padded = ".\(o.ext)".padding(
                    toLength: maxLen + 2, withPad: " ", startingAt: 0)
                print("  \(padded) \(o.handler)")
            }
        }
        print()

        // UNCLAIMED
        print("UNCLAIMED (\(unclaimed.count))")
        if unclaimed.isEmpty {
            print("  (none)")
        } else {
            print("  \(unclaimed.map { ".\($0)" }.joined(separator: " "))")
        }
        print()

        // Summary
        let total = statuses.count
        print("\(total) extensions: " +
              "\(registered.count) registered, \(claimed.count) claimed, " +
              "\(other.count) other, \(unclaimed.count) unclaimed")
    }

    // MARK: - claim

    private static func handleClaim(_ args: [String]) {
        let claimAll = args.contains("--all")
        let statuses = ExtensionRegistry.queryAllStatuses()

        // Count plist-registered extensions for messaging
        let registeredCount = statuses.filter { $0.status == .registered }.count

        let toClaim: [String]
        if claimAll {
            // Claim unclaimed + contested (other); skip registered + claimed
            toClaim = statuses.compactMap { s in
                switch s.status {
                case .registered, .claimed: return nil
                case .other, .unclaimed: return s.ext
                }
            }
        } else {
            // Claim unclaimed only
            toClaim = statuses.compactMap { s in
                s.status == .unclaimed ? s.ext : nil
            }
        }

        // Pre-claim messaging
        if registeredCount > 0 {
            print("\(registeredCount) extensions are automatically registered " +
                  "via Info.plist (no action needed).")
        }

        if toClaim.isEmpty {
            print("Nothing to claim.")
            exit(exitSuccess)
        }

        print("Claiming \(toClaim.count) remaining extension(s)" +
              " \u{2014} macOS may show confirmation dialogs.")
        print()

        let results = ExtensionRegistry.claim(extensions: toClaim)
        let succeeded = results.filter { $0.result == .success }
        let skipped = results.filter { $0.result == .skipped }
        let failed = results.filter { $0.result == .failed }

        if !succeeded.isEmpty {
            print("Claimed \(succeeded.count) extension(s):")
            print("  \(succeeded.map { ".\($0.ext)" }.joined(separator: " "))")

            // Update ConfigStore's claimed list
            let store = ConfigStore.shared
            var current = Set(store.claimedExtensions)
            for r in succeeded { current.insert(r.ext) }
            store.claimedExtensions = Array(current).sorted()
        }

        // Summary line
        print()
        print("\(succeeded.count) claimed, \(failed.count) failed, " +
              "\(skipped.count) skipped (plist-registered).")

        if !failed.isEmpty {
            printErr("Failed extension(s):")
            printErr("  \(failed.map { ".\($0.ext)" }.joined(separator: " "))")
            exit(exitError)
        }

        exit(exitSuccess)
    }

    // MARK: - release

    private static func handleRelease(_ args: [String]) {
        // Release is the inverse of claim — planned for a future version (TR-07).
        printErr("The release command is planned for a future version.")
        printErr("For now, use Finder > Get Info > Open With to change individual handlers.")
        exit(exitSuccess)  // Not an error, just not implemented yet
    }

    // MARK: - install-cli

    /// Create `/usr/local/bin/trampoline` symlink pointing to the current
    /// executable. Exposed as a separate method so the GUI can call it too.
    ///
    /// Fast path: uses `FileManager` directly when the process already has
    /// write access (e.g. `sudo make install`).
    /// Slow path: falls back to `NSAppleScript` with `administrator privileges`
    /// to trigger the standard macOS password prompt.
    static func installCLI() -> (success: Bool, message: String) {
        guard let executablePath = Bundle.main.executablePath else {
            return (false,
                    "Could not determine executable path from bundle.")
        }
        let symlinkPath = "/usr/local/bin/trampoline"
        let dir = "/usr/local/bin"
        let fm = FileManager.default

        // Fast path: direct symlink creation when we already have permissions
        if fm.isWritableFile(atPath: dir) {
            if fm.fileExists(atPath: symlinkPath) {
                do {
                    try fm.removeItem(atPath: symlinkPath)
                } catch {
                    return (false,
                            "Could not remove existing \(symlinkPath): \(error.localizedDescription)")
                }
            }
            do {
                try fm.createSymbolicLink(
                    atPath: symlinkPath, withDestinationPath: executablePath)
            } catch {
                return (false,
                        "Could not create symlink: \(error.localizedDescription)")
            }
            return (true,
                    "Symlink created: \(symlinkPath) -> \(executablePath)")
        }

        // Slow path: privilege escalation via macOS admin prompt
        let escapedPath = executablePath
            .replacingOccurrences(of: "'", with: "'\\''")
        let shellCmd = "mkdir -p '\(dir)'"
            + " && rm -f '\(symlinkPath)'"
            + " && ln -sf '\(escapedPath)' '\(symlinkPath)'"
        // Escape backslashes and double-quotes for the AppleScript string layer
        let appleScriptSafe = shellCmd
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let source = "do shell script \"\(appleScriptSafe)\" with administrator privileges"

        guard let script = NSAppleScript(source: source) else {
            return (false,
                    "Could not create privilege-escalation script.")
        }

        var errorInfo: NSDictionary?
        script.executeAndReturnError(&errorInfo)

        if let info = errorInfo {
            let code = (info[NSAppleScript.errorNumber] as? Int) ?? 0
            if code == -128 {
                return (false, "Installation cancelled.")
            }
            let desc = (info[NSAppleScript.errorMessage] as? String)
                ?? "Unknown error (code \(code))"
            return (false,
                    "Could not create symlink with admin privileges: \(desc)")
        }

        return (true,
                "Symlink created: \(symlinkPath) -> \(executablePath)")
    }

    private static func handleInstallCLI() {
        let result = installCLI()
        if result.success {
            print(result.message)
            exit(exitSuccess)
        } else {
            printErr(result.message)
            exit(exitError)
        }
    }

    // MARK: - uninstall

    private static func handleUninstall() {
        let fm = FileManager.default
        var hadError = false

        // Remove symlink
        let symlinkPath = "/usr/local/bin/trampoline"
        if fm.fileExists(atPath: symlinkPath) {
            do {
                try fm.removeItem(atPath: symlinkPath)
                print("Removed \(symlinkPath)")
            } catch {
                printErr("Could not remove \(symlinkPath): \(error.localizedDescription)")
                hadError = true
            }
        } else {
            print("No symlink at \(symlinkPath)")
        }

        // Clear UserDefaults
        let bundleID = ExtensionRegistry.trampolineBundleID
        UserDefaults.standard.removePersistentDomain(forName: bundleID)
        print("Cleared preferences (\(bundleID))")

        exit(hadError ? exitError : exitSuccess)
    }

    // MARK: - Help

    private static func printUsage() {
        let usage = """
        Trampoline - Developer file handler for macOS

        USAGE:
            trampoline <command> [options]

        COMMANDS:
            editor [name|bundle-id]    Get or set the default editor
            extensions <action>        Manage custom file extensions
            status                     Show extension handler status
            claim [--all]              Claim extensions as Trampoline
            release [--all]            Release extensions back to system
            install-cli                Create /usr/local/bin/trampoline symlink
            uninstall                  Remove CLI, clear preferences

        OPTIONS:
            -h, --help                 Show this help
            -v, --version              Show version

        EXAMPLES:
            trampoline editor                    Show current editor
            trampoline editor zed                Set Zed as default
            trampoline editor com.microsoft.VSCode  Set by bundle ID
            trampoline editor --list                    Show all editor overrides
            trampoline editor .rs                       Show editor for .rs
            trampoline editor .kt,.kts intellij         Override editor for extensions
            trampoline editor .kt --clear               Clear override, use default
            trampoline status                    Show all extensions
            trampoline status --json             Machine-readable output
            trampoline extensions add .typ .roc    Add custom extensions
            trampoline extensions list             List custom extensions
            trampoline claim                     Claim unclaimed only
            trampoline claim --all               Claim all (may show dialogs)
        """
        print(usage)
    }

    // MARK: - Helpers

    /// Resolves an editor input string (shorthand, bundle ID, or display name)
    /// to a (bundleID, displayName) pair. Returns nil if unresolvable.
    private static func resolveEditorInput(
        _ input: String
    ) -> (bundleID: String, displayName: String)? {
        if let entry = EditorShorthands.resolve(input) {
            return (entry.bundleID, entry.displayName)
        }
        if input.contains(".") {
            let displayName: String
            if let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: input
            ) {
                displayName = appURL.deletingPathExtension().lastPathComponent
            } else {
                displayName = input
            }
            return (input, displayName)
        }
        return nil
    }

    private static func printErr(_ message: String) {
        FileHandle.standardError.write(
            Data((message + "\n").utf8))
    }
}
