import AppKit
import SwiftUI

// MARK: - Settings Window

/// NSWindow-based settings window. We use NSHostingController because the app
/// uses NSApplicationDelegate, not the SwiftUI App protocol.
enum SettingsWindow {

    // MARK: - Shared state

    static var shared: NSWindow?

    // MARK: - Show

    static func show() {
        if shared == nil {
            let contentView = SettingsContentView()
            let hostingController = NSHostingController(rootView: contentView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = "Trampoline"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 640, height: 520))
            window.minSize = NSSize(width: 540, height: 440)
            window.maxSize = NSSize(width: 800, height: 640)
            window.center()
            window.isReleasedWhenClosed = false

            let delegate = SettingsWindowDelegate()
            window.delegate = delegate
            objc_setAssociatedObject(
                window, &SettingsWindowDelegate.associatedKey,
                delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            shared = window
        }

        guard let window = shared else { return }

        // Reliable focus acquisition for a menu bar agent (.accessory):
        //
        // The challenge: when the user clicks a status item menu action,
        // macOS dismisses the menu and returns focus to the previously
        // active app BEFORE our action handler runs. So the sequence is:
        //   1. User clicks "Settings..." in status menu
        //   2. macOS closes the menu, re-focuses Safari (or whatever)
        //   3. Our openSettings() runs — but we're not the active app
        //
        // The fix (from boring.notch, Loop, and other proven menu bar apps):
        //   1. Switch to .regular so macOS allows us to own focus
        //   2. orderFrontRegardless — shows the window even when not active
        //   3. activate(ignoringOtherApps:) — forcefully take active status
        //   4. DispatchQueue.main.async — re-assert focus on the NEXT
        //      runloop iteration, after macOS finishes the policy transition
        NSApp.setActivationPolicy(.regular)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Re-assert focus after macOS finishes the activation transition
        DispatchQueue.main.async {
            window.makeKeyAndOrderFront(nil)
        }
    }

    static func showWithWarning(_ message: String) {
        ConfigStore.shared.warningMessage = message
        show()
    }
}

// MARK: - Window Delegate

private class SettingsWindowDelegate: NSObject, NSWindowDelegate {

    static var associatedKey: UInt8 = 0

    func windowDidBecomeKey(_ notification: Notification) {
        // Re-ensure .regular policy when the window gains focus.
        // Handles edge cases where macOS reverts the policy.
        NSApp.setActivationPolicy(.regular)
    }

    func windowWillClose(_ notification: Notification) {
        SettingsWindow.shared = nil
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - SwiftUI Content

private struct SettingsContentView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ExtensionsTab()
                .tabItem {
                    Label("Extensions", systemImage: "doc.plaintext")
                }

            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .tabViewStyle(.automatic)
    }
}
