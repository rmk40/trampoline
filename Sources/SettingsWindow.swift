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
            window.setContentSize(NSSize(width: 640, height: 480))
            window.minSize = NSSize(width: 540, height: 400)
            window.maxSize = NSSize(width: 800, height: 600)
            window.center()

            let delegate = SettingsWindowDelegate()
            window.delegate = delegate
            objc_setAssociatedObject(
                window, &SettingsWindowDelegate.associatedKey,
                delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

            shared = window
        }

        guard let window = shared else { return }

        // For a menu bar agent (.accessory), the activation sequence must be:
        // 1. Switch to .regular so the app CAN receive focus
        // 2. Show the window with orderFrontRegardless (works even when
        //    the app isn't yet the active app — makeKeyAndOrderFront
        //    silently fails in that case)
        // 3. Make it the key window
        // 4. Activate the app (bring it to front)
        // The delay ensures macOS has finished the activation policy
        // transition before we request focus.
        NSApp.setActivationPolicy(.regular)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
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
