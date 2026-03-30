import AppKit

/// Manages the optional NSStatusItem in the macOS menu bar.
/// Visibility is driven by `ConfigStore.shared.showMenuBarIcon`.
@MainActor
final class MenuBarManager: NSObject, NSMenuDelegate {

    static let shared = MenuBarManager()

    override private init() {
        super.init()
    }

    private var statusItem: NSStatusItem?

    // MARK: - Setup / Teardown

    /// Creates the status item if `showMenuBarIcon` is true and starts
    /// observing the config flag for future changes.
    func setup() {
        updateVisibility()
        startObserving()
    }

    /// Removes the status item from the menu bar.
    func teardown() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    // MARK: - Visibility

    /// Shows or hides the status item based on the current config value.
    func updateVisibility() {
        if ConfigStore.shared.showMenuBarIcon {
            if statusItem == nil {
                createStatusItem()
            }
        } else {
            teardown()
        }
    }

    // MARK: - Menu refresh

    /// Rebuilds the menu with current editor name and extension count.
    func updateMenu() {
        guard let menu = statusItem?.menu else { return }

        menu.removeAllItems()

        let editorName = ConfigStore.shared.editorDisplayName ?? "None"
        let overrideCount = ConfigStore.shared.editorOverrides.count
        let editorTitle: String
        if overrideCount > 0 {
            editorTitle = "Editor: \(editorName) (+\(overrideCount) override\(overrideCount == 1 ? "" : "s"))"
        } else {
            editorTitle = "Editor: \(editorName)"
        }
        let editorItem = NSMenuItem(
            title: editorTitle, action: nil, keyEquivalent: "")
        editorItem.isEnabled = false
        menu.addItem(editorItem)

        let count = ExtensionRegistry.all.count
        let extItem = NSMenuItem(
            title: "\(count) extensions managed", action: nil, keyEquivalent: "")
        extItem.isEnabled = false
        menu.addItem(extItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings…", action: #selector(openSettings),
            keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Trampoline", action: #selector(quitApp),
            keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    // MARK: - Private

    private func createStatusItem() {
        let item = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength)

        if let button = item.button {
            let image = NSImage(
                systemSymbolName: "arrow.up.right.square",
                accessibilityDescription: "Trampoline")
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu

        statusItem = item
    }

    // MARK: - NSMenuDelegate

    /// Rebuilds menu items on demand so the menu always reflects current state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        updateMenu()
    }

    /// Observes `showMenuBarIcon` via Swift Observation's
    /// `withObservationTracking` and re-evaluates visibility on change.
    private func startObserving() {
        withObservationTracking {
            _ = ConfigStore.shared.showMenuBarIcon
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateVisibility()
                self?.startObserving()
            }
        }
    }

    // MARK: - Actions

    @objc private func openSettings() {
        SettingsWindow.show()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
