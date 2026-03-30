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
        if let window = shared {
            window.makeKeyAndOrderFront(nil)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate()
            return
        }

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
        // Prevent delegate from being deallocated while the window is alive.
        // Stored as an associated object on the window itself.
        objc_setAssociatedObject(
            window, &SettingsWindowDelegate.associatedKey,
            delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        shared = window
        window.makeKeyAndOrderFront(nil)
        NSApp.setActivationPolicy(.regular)
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
