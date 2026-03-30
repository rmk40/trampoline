import SwiftUI
import UniformTypeIdentifiers

// MARK: - Extension status counts

private struct ExtensionCounts {
    let total: Int
    let claimed: Int
    let other: Int
    let unclaimed: Int

    /// Extensions eligible for "Claim Unclaimed" (unclaimed only).
    let unclaimedExts: [String]
    /// Extensions eligible for "Claim All" (unclaimed + other).
    let claimableExts: [String]
}

// MARK: - General Tab

struct GeneralTab: View {

    @State private var editors: [EditorInfo] = []
    @State private var selectedBundleID: String = ""
    @State private var counts: ExtensionCounts?
    @State private var cliMessage: String?
    @State private var cliSuccess: Bool?
    @State private var pendingCount: Int = 0

    @Bindable private var config = ConfigStore.shared

    var body: some View {
        Form {
            editorSection
            infoBanner
            controlsRow
            extensionSection
        }
        .formStyle(.grouped)
        .onAppear(perform: loadData)
    }

    // MARK: - Editor picker

    private var editorSection: some View {
        Section {
            Picker("Default Editor", selection: $selectedBundleID) {
                if !editors.contains(where: { $0.bundleID == selectedBundleID }) {
                    Text("Choose…").tag("")
                }
                ForEach(editors) { editor in
                    Label {
                        Text(editor.displayName)
                    } icon: {
                        Image(nsImage: resizedIcon(editor.icon))
                    }
                    .tag(editor.bundleID)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: selectedBundleID) { _, newValue in
                editorDidChange(newValue)
            }

            Button("Browse…") {
                browseForEditor()
            }
        }
    }

    // MARK: - Info banner

    private var infoBanner: some View {
        Section {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                Group {
                    if selectedBundleID.isEmpty {
                        Text("Choose an editor to get started.")
                    } else if pendingCount > 0 {
                        let name = config.editorDisplayName ?? "your editor"
                        Text("\(pendingCount) file(s) waiting. Files will be forwarded to \(name).")
                    } else {
                        let name = config.editorDisplayName ?? "your editor"
                        Text("When you open a developer file, Trampoline will forward it to \(name).")
                    }
                }
                .foregroundStyle(.secondary)
                .font(.callout)
            }

            if let warning = config.warningMessage {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                    Text(warning)
                        .foregroundStyle(.primary)
                        .font(.callout)
                }
            }
        }
    }

    // MARK: - Controls row

    private var controlsRow: some View {
        Section {
            HStack {
                Toggle("Show in menu bar", isOn: $config.showMenuBarIcon)
                Spacer()
                Button("Install CLI…") {
                    let result = CLIHandler.installCLI()
                    cliSuccess = result.success
                    cliMessage = result.message
                }
            }

            if let message = cliMessage {
                Label(
                    message,
                    systemImage: cliSuccess == true
                        ? "checkmark.circle" : "xmark.circle"
                )
                .foregroundStyle(cliSuccess == true ? .green : .red)
                .font(.callout)
            }
        }
    }

    // MARK: - Extension status

    private var extensionSection: some View {
        Section("Extension Status") {
            if let c = counts {
                Text("\(c.total) managed  |  \(c.claimed) claimed  |  \(c.other) other  |  \(c.unclaimed) unclaimed")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Claim Unclaimed (\(c.unclaimedExts.count))") {
                        claimExtensions(c.unclaimedExts)
                    }
                    .disabled(c.unclaimedExts.isEmpty)

                    Button("Claim All (\(c.claimableExts.count))") {
                        claimExtensions(c.claimableExts)
                    }
                    .disabled(c.claimableExts.isEmpty)
                }
            } else {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Actions

    private func loadData() {
        editors = EditorDetector.detectInstalledEditors()
        selectedBundleID = config.editorBundleID ?? ""
        pendingCount = FileForwarder.shared.pendingFiles.count
        refreshCounts()
    }

    private func editorDidChange(_ bundleID: String) {
        guard !bundleID.isEmpty else { return }
        guard let editor = editors.first(where: { $0.bundleID == bundleID }) else {
            return
        }

        config.editorBundleID = editor.bundleID
        config.editorDisplayName = editor.displayName

        if !FileForwarder.shared.pendingFiles.isEmpty {
            _ = FileForwarder.shared.retryPending()
        }
        pendingCount = FileForwarder.shared.pendingFiles.count

        if !config.firstRunComplete {
            config.firstRunComplete = true
        }

        // Clear the warning once an editor is chosen.
        config.warningMessage = nil
    }

    private func claimExtensions(_ exts: [String]) {
        guard !exts.isEmpty else { return }
        ExtensionRegistry.claim(extensions: exts)

        // Update ConfigStore's claimed list to match CLI behavior.
        var current = Set(config.claimedExtensions)
        for ext in exts { current.insert(ext) }
        config.claimedExtensions = Array(current).sorted()

        refreshCounts()
    }

    private func refreshCounts() {
        let statuses = ExtensionRegistry.queryAllStatuses()

        var claimed = 0
        var other = 0
        var unclaimed = 0
        var unclaimedExts = [String]()
        var claimableExts = [String]()

        for s in statuses {
            switch s.status {
            case .claimed:
                claimed += 1
            case .other:
                other += 1
                claimableExts.append(s.ext)
            case .unclaimed:
                unclaimed += 1
                unclaimedExts.append(s.ext)
                claimableExts.append(s.ext)
            }
        }

        counts = ExtensionCounts(
            total: statuses.count,
            claimed: claimed,
            other: other,
            unclaimed: unclaimed,
            unclaimedExts: unclaimedExts,
            claimableExts: claimableExts)
    }

    private func browseForEditor() {
        let panel = NSOpenPanel()
        panel.title = "Choose an Editor"
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else {
            return
        }

        let displayName = bundle.infoDictionary?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent

        let icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        icon.size = NSSize(width: 32, height: 32)

        let editor = EditorInfo(
            bundleID: bundleID,
            displayName: displayName,
            shorthand: nil,
            appURL: url,
            icon: icon
        )

        // Add to the list if not already present.
        if !editors.contains(where: { $0.bundleID == bundleID }) {
            editors.append(editor)
        }

        selectedBundleID = bundleID
    }

    // MARK: - Helpers

    private func resizedIcon(_ icon: NSImage) -> NSImage {
        guard let copy = icon.copy() as? NSImage else { return icon }
        copy.size = NSSize(width: 16, height: 16)
        return copy
    }
}
