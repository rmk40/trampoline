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

        // GUI / file-forwarding mode — launch as menu bar agent.
        // The app lives in the menu bar; no Dock icon by default.
        MenuBarManager.shared.setup()
        NSLog("Trampoline ready")

        // Only show settings automatically on first run (no editor configured).
        // On subsequent launches, the app sits silently in the menu bar.
        if !ConfigStore.shared.firstRunComplete {
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

    // MARK: Menu bar actions (for main menu keyboard shortcuts)

    @objc func showSettings() {
        SettingsWindow.show()
    }

    @objc func showSettingsAbout() {
        SettingsWindow.show()
    }
}

// MARK: - Entry point

@main
enum Trampoline {
    static let appDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.mainMenu = buildMainMenu()
        app.run()
    }

    /// Builds the application main menu so Cmd+Q and other standard
    /// shortcuts work. Status item menus don't participate in the
    /// key-event responder chain, so without this, no keyboard
    /// shortcuts function.
    private static func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        // Application menu (shows as "Trampoline" in the menu bar)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Trampoline",
                        action: #selector(AppDelegate.showSettingsAbout),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings\u{2026}",
                        action: #selector(AppDelegate.showSettings),
                        keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Trampoline",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // Window menu (enables Cmd+W to close the settings window)
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize",
                           action: #selector(NSWindow.miniaturize(_:)),
                           keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close",
                           action: #selector(NSWindow.performClose(_:)),
                           keyEquivalent: "w")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        return mainMenu
    }
}
