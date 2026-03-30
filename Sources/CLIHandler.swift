import AppKit
import Foundation

/// Parses `CommandLine.arguments` and dispatches CLI subcommands.
/// No external arg-parsing library — pure Foundation.
enum CLIHandler {

    // MARK: - Constants

    static let subcommands: Set<String> = [
        "editor", "status", "claim", "release", "install-cli", "uninstall",
        "--help", "--version", "-h", "-v",
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
        case "editor":    handleEditor(rest)
        case "status":    handleStatus(rest)
        case "claim":     handleClaim(rest)
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

        // Try resolving via EditorShorthands
        if let entry = EditorShorthands.resolve(input) {
            store.editorBundleID = entry.bundleID
            store.editorDisplayName = entry.displayName
            print("Default editor set to: \(entry.displayName) (\(entry.bundleID))")
            exit(exitSuccess)
        }

        // If input contains a dot, treat as raw bundle ID
        if input.contains(".") {
            let displayName: String
            if let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: input
            ) {
                displayName = appURL.deletingPathExtension().lastPathComponent
            } else {
                displayName = input
            }
            store.editorBundleID = input
            store.editorDisplayName = displayName
            print("Default editor set to: \(displayName) (\(input))")
            exit(exitSuccess)
        }

        printErr("Unknown editor: \(input)")
        printErr("Use a shorthand (e.g., zed, vscode) or a bundle ID (e.g., com.microsoft.VSCode)")
        exit(exitError)
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
        let entries: [[String: String]] = statuses.map { s in
            var dict: [String: String] = ["ext": s.ext]
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
    static func installCLI() -> (success: Bool, message: String) {
        guard let executablePath = Bundle.main.executablePath else {
            return (false,
                    "Could not determine executable path from bundle.")
        }
        let symlinkPath = "/usr/local/bin/trampoline"
        let fm = FileManager.default

        // Ensure /usr/local/bin exists
        let dir = "/usr/local/bin"
        if !fm.fileExists(atPath: dir) {
            return (false,
                    "\(dir) does not exist. Create it first or use Homebrew.")
        }

        // Remove existing symlink if present
        if fm.fileExists(atPath: symlinkPath) {
            do {
                try fm.removeItem(atPath: symlinkPath)
            } catch {
                return (false,
                        "Could not remove existing \(symlinkPath): \(error.localizedDescription)")
            }
        }

        // Create symlink
        do {
            try fm.createSymbolicLink(
                atPath: symlinkPath, withDestinationPath: executablePath)
        } catch {
            return (false,
                    "Could not create symlink: \(error.localizedDescription)")
        }

        return (true, "Symlink created: \(symlinkPath) -> \(executablePath)")
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
            trampoline status                    Show all extensions
            trampoline status --json             Machine-readable output
            trampoline claim                     Claim unclaimed only
            trampoline claim --all               Claim all (may show dialogs)
        """
        print(usage)
    }

    // MARK: - Helpers

    private static func printErr(_ message: String) {
        FileHandle.standardError.write(
            Data((message + "\n").utf8))
    }
}
