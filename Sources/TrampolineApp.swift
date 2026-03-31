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

        // --- Move-to-Applications check ---
        let bundlePath = Bundle.main.bundlePath
        let homePath = NSHomeDirectory()
        let validPrefixes = ["/Applications/", homePath + "/Applications/"]
        let isInstalled = validPrefixes.contains { bundlePath.hasPrefix($0) }

        if !isInstalled && !ConfigStore.shared.suppressMovePrompt {
            let onDMG = bundlePath.hasPrefix("/Volumes/")
            let action = showMoveToApplicationsAlert(forcedMove: onDMG)
            switch action {
            case .move:
                if moveToApplications() { return }
            case .quit:
                NSApp.terminate(nil)
                return
            case .notNow:
                break
            case .dontAskAgain:
                ConfigStore.shared.suppressMovePrompt = true
            }
        }

        // --- Self-register with LaunchServices ---
        if isInstalled,
           ConfigStore.shared.lsRegisteredVersion != ExtensionRegistry.version {
            selfRegisterWithLaunchServices()
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
            let overrideCount = ConfigStore.shared.editorOverrides.count
            let message: String
            if overrideCount > 0 {
                message = "One or more configured editors could not be found. Check your settings."
            } else {
                let name = ConfigStore.shared.editorDisplayName
                    ?? ConfigStore.shared.editorBundleID ?? "Editor"
                message = "\(name) is no longer installed. Choose a different editor."
            }
            NSLog("Trampoline: editor not found — %d file(s) queued",
                  urls.count)
            SettingsWindow.showWithWarning(message)
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

    // MARK: - Move-to-Applications (DMG-01)

    private enum MoveAction {
        case move, quit, notNow, dontAskAgain
    }

    private func showMoveToApplicationsAlert(forcedMove: Bool) -> MoveAction {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational

        if forcedMove {
            alert.messageText = "Move to Applications"
            alert.informativeText = "Trampoline is running from a disk image. "
                + "It must be installed in your Applications folder to work properly."
            alert.addButton(withTitle: "Move to Applications")
            alert.addButton(withTitle: "Quit")
            let response = alert.runModal()
            return response == .alertFirstButtonReturn ? .move : .quit
        } else {
            alert.messageText = "Move to Applications?"
            alert.informativeText = "Trampoline works best when installed in your "
                + "Applications folder. Would you like to move it there now?"
            alert.addButton(withTitle: "Move to Applications")
            alert.addButton(withTitle: "Not Now")
            alert.addButton(withTitle: "Don't Ask Again")
            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn: return .move
            case .alertSecondButtonReturn: return .notNow
            default: return .dontAskAgain
            }
        }
    }

    /// Attempts to move the app to /Applications and relaunch.
    /// Returns `true` if relaunch was initiated (caller should return).
    private func moveToApplications() -> Bool {
        let source = Bundle.main.bundleURL
        let dest = URL(fileURLWithPath: "/Applications/Trampoline.app")
        let tempDest = URL(fileURLWithPath: "/Applications/Trampoline.app.new")
        let fm = FileManager.default

        // Clean up any stale temp from a previous failed attempt
        try? fm.removeItem(at: tempDest)

        // Try move first (atomic on same volume), fall back to copy.
        // moveItem may leave a partial directory on cross-volume failure,
        // so clear tempDest before the copy fallback.
        do {
            try fm.moveItem(at: source, to: tempDest)
        } catch {
            // Cross-volume (e.g., DMG) — clean up partial and fall back to copy
            try? fm.removeItem(at: tempDest)
            do {
                try fm.copyItem(at: source, to: tempDest)
                // Try to clean up source (fails silently on read-only volumes)
                try? fm.removeItem(at: source)
            } catch {
                showMoveErrorAlert(
                    "Could not install Trampoline: \(error.localizedDescription)\n\n"
                    + "Drag Trampoline.app from Finder into your Applications folder, "
                    + "then relaunch.")
                try? fm.removeItem(at: tempDest)
                return false
            }
        }

        // Replace existing install: remove old, rename temp to final.
        // If remove succeeds but rename fails, attempt recovery by
        // renaming temp back so the user isn't left without an install.
        do {
            if fm.fileExists(atPath: dest.path) {
                try fm.removeItem(at: dest)
            }
            try fm.moveItem(at: tempDest, to: dest)
        } catch {
            // Recovery: if dest was removed but rename failed, try to
            // put the temp copy at the final path anyway.
            if !fm.fileExists(atPath: dest.path),
               fm.fileExists(atPath: tempDest.path) {
                try? fm.moveItem(at: tempDest, to: dest)
            }
            showMoveErrorAlert(
                "Could not replace existing installation: \(error.localizedDescription)\n\n"
                + "Drag Trampoline.app from Finder into your Applications folder, "
                + "then relaunch.")
            return false
        }

        // Relaunch from installed location
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [dest.path]
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                NSLog("Trampoline: open exited with status %d",
                      task.terminationStatus)
                showMoveErrorAlert(
                    "Trampoline was installed but could not be relaunched. "
                    + "Open it from your Applications folder.")
                return false
            }
        } catch {
            NSLog("Trampoline: failed to relaunch: %@",
                  error.localizedDescription)
            showMoveErrorAlert(
                "Trampoline was installed but could not be relaunched. "
                + "Open it from your Applications folder.")
            return false
        }
        NSApp.terminate(nil)
        return true
    }

    private func showMoveErrorAlert(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Installation Failed"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - LaunchServices self-registration (DMG-02)

    private func selfRegisterWithLaunchServices() {
        let lsregister = "/System/Library/Frameworks/CoreServices.framework"
            + "/Frameworks/LaunchServices.framework/Support/lsregister"
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: lsregister)
        task.arguments = ["-f", bundlePath]
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                ConfigStore.shared.lsRegisteredVersion = ExtensionRegistry.version
                NSLog("Trampoline: registered with LaunchServices (v%@)",
                      ExtensionRegistry.version)
            } else {
                NSLog("Trampoline: lsregister exited with status %d",
                      task.terminationStatus)
            }
        } catch {
            NSLog("Trampoline: failed to run lsregister: %@",
                  error.localizedDescription)
        }
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
