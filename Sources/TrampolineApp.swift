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

        // Show settings if no files are pending (e.g. launched from Dock).
        if FileForwarder.shared.pendingFiles.isEmpty {
            SettingsWindow.show()
        }
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
            SettingsWindow.showWithWarning(
                "Choose an editor to open your files")
        case .editorNotFound:
            let name = ConfigStore.shared.editorDisplayName
                ?? ConfigStore.shared.editorBundleID ?? "Editor"
            NSLog("Trampoline: editor not found — %d file(s) queued",
                  urls.count)
            SettingsWindow.showWithWarning(
                "\(name) is no longer installed. Choose a different editor.")
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
        SettingsWindow.show()
        return true
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
