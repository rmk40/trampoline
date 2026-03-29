import AppKit

// MARK: - CLI subcommands recognised at launch

private let cliSubcommands: Set<String> = [
    "editor", "status", "claim", "install-cli", "uninstall",
    "--help", "--version", "-h", "-v",
]

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {

    private var isCLIMode = false

    // MARK: Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        let isCLI = args.count > 1 && cliSubcommands.contains(args[1])

        if isCLI {
            isCLIMode = true
            NSLog("Trampoline: CLI mode detected — not yet implemented")
            print("CLI mode: not yet implemented")
            // Safe to exit here: we are in CLI mode before any AppKit windows
            // or run-loop state have been initialised.
            exit(0)
        }

        // GUI / file-forwarding mode
        NSLog("Trampoline ready")
    }

    // MARK: File open events

    func application(_ application: NSApplication, open urls: [URL]) {
        let result = FileForwarder.shared.forward(urls: urls)

        switch result {
        case .success:
            break
        case .noEditor:
            NSLog("Trampoline: no editor configured — %d file(s) queued",
                  urls.count)
        case .editorNotFound:
            if let id = ConfigStore.shared.editorBundleID {
                NSLog("Trampoline: editor %@ not found — %d file(s) queued",
                      id, urls.count)
            }
        }
    }

    // MARK: Lifecycle

    func applicationShouldTerminateAfterLastWindowClosed(
        _ sender: NSApplication
    ) -> Bool {
        false
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        // Will show settings window in TR-06
        true
    }
}

// MARK: - Entry point

@main
enum Trampoline {
    static let appDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.run()
    }
}
