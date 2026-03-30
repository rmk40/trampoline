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

// MARK: - Banner style

/// Visual style for the info/warning banners in GeneralTab.
/// Each flow uses a distinct style so the user can tell at a glance
/// whether they're in first-run, normal, or error-recovery mode.
private enum BannerStyle {
    case welcome   // F-01: first-run — blue tint
    case info      // Normal operation — gray/secondary
    case warning   // F-08/F-09: error recovery — orange/yellow tint

    var iconName: String {
        switch self {
        case .welcome: return "hand.wave.fill"
        case .info:    return "info.circle"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    var iconColor: Color {
        switch self {
        case .welcome: return .blue
        case .info:    return .secondary
        case .warning: return .orange
        }
    }

    var backgroundColor: Color {
        switch self {
        case .welcome: return .blue
        case .info:    return .gray
        case .warning: return .orange
        }
    }

    var textColor: Color {
        switch self {
        case .welcome: return .primary
        case .info:    return .secondary
        case .warning: return .primary
        }
    }
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

    /// True when the user is in first-run mode AND has not yet picked an editor.
    private var isFirstRunPending: Bool {
        !config.firstRunComplete && selectedBundleID.isEmpty
    }

    /// True when the user is in first-run mode but has already picked an editor
    /// (extension section should now be visible).
    private var isFirstRunEditorChosen: Bool {
        !config.firstRunComplete && !selectedBundleID.isEmpty
    }

    var body: some View {
        Form {
            if isFirstRunPending {
                welcomeBanner
            }

            editorSection

            if !isFirstRunPending {
                statusBanner
                controlsRow
                extensionSection
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: loadData)
        .onChange(of: config.warningMessage) { _, _ in
            pendingCount = FileForwarder.shared.pendingFiles.count
        }
    }

    // MARK: - Welcome banner (F-01 first-run)

    private var welcomeBanner: some View {
        Section {
            bannerCard(
                style: .welcome,
                title: "Welcome to Trampoline",
                body: "Trampoline makes developer files open in your preferred code editor. Choose your editor below to get started."
            )
        }
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

    // MARK: - Status banner (info / warning / pending)

    private var statusBanner: some View {
        Section {
            // Warning banner (F-08/F-09 recovery) takes priority
            if let warning = config.warningMessage {
                bannerCard(style: .warning, title: nil, body: warning)
            } else if selectedBundleID.isEmpty && pendingCount > 0 {
                // F-08: pending files but no editor selected yet
                bannerRow(
                    style: .warning,
                    text: "\(pendingCount) file(s) waiting. Choose an editor to open them."
                )
            } else if selectedBundleID.isEmpty {
                bannerRow(
                    style: .info,
                    text: "Choose an editor to get started."
                )
            } else if pendingCount > 0 {
                let name = config.editorDisplayName ?? "your editor"
                bannerRow(
                    style: .info,
                    text: "\(pendingCount) file(s) waiting. Files will be forwarded to \(name)."
                )
            } else if isFirstRunEditorChosen, let c = counts, !c.unclaimedExts.isEmpty {
                bannerRow(
                    style: .info,
                    text: "\(c.unclaimedExts.count) unclaimed extension(s) found. Click \"Claim Unclaimed\" below to register them."
                )
            } else {
                let name = config.editorDisplayName ?? "your editor"
                bannerRow(
                    style: .info,
                    text: "When you open a developer file, Trampoline will forward it to \(name)."
                )
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

    // MARK: - Banner components

    /// A styled card banner with optional title and body text.
    /// Used for welcome (first-run) and warning (error recovery) banners.
    private func bannerCard(
        style: BannerStyle,
        title: String?,
        body: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: style.iconName)
                .font(.title2)
                .foregroundStyle(style.iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                Text(body)
                    .font(.callout)
                    .foregroundStyle(style.textColor)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.backgroundColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    /// A compact single-line banner row with icon and text.
    /// Used for contextual info messages.
    private func bannerRow(style: BannerStyle, text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: style.iconName)
                .foregroundStyle(style.iconColor)
            Text(text)
                .foregroundStyle(style.textColor)
                .font(.callout)
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

        // Retry any pending files (F-08/F-09 recovery).
        if !FileForwarder.shared.pendingFiles.isEmpty {
            _ = FileForwarder.shared.retryPending()
        }
        pendingCount = FileForwarder.shared.pendingFiles.count

        // Mark first-run complete once an editor is chosen (F-01).
        // This hides the welcome banner and reveals the extension section.
        if !config.firstRunComplete {
            config.firstRunComplete = true
        }

        // Clear the warning once an editor is chosen (F-08/F-09).
        config.warningMessage = nil

        // Refresh extension counts so the "Claim Unclaimed (N)" button
        // shows the correct number immediately after editor selection.
        refreshCounts()
    }

    private func claimExtensions(_ exts: [String]) {
        guard !exts.isEmpty else { return }
        ExtensionRegistry.claim(extensions: exts)

        // Update ConfigStore's claimed list to match CLI behavior.
        var current = Set(config.claimedExtensions)
        for ext in exts { current.insert(ext) }
        config.claimedExtensions = Array(current).sorted()

        // Mark first-run complete after claiming (F-01).
        if !config.firstRunComplete {
            config.firstRunComplete = true
        }

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
