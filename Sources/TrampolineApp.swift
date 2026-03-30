import AppKit

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {

    private var isCLIMode = false

    // MARK: Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        let isCLI = args.count > 1 && CLIHandler.subcommands.contains(args[1])

        if isCLI {
            isCLIMode = true
            CLIHandler.run()
            // CLIHandler.run() calls exit() — this line is unreachable,
            // but kept as a safety net.
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
