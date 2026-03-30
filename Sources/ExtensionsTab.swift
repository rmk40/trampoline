import SwiftUI

// MARK: - Row model

private struct ExtensionRow: Identifiable {
    let ext: String
    var handlerName: String
    var status: HandlerStatus
    var editorName: String       // resolved editor display name
    var hasOverride: Bool        // true if ext has per-extension override
    var isSelected: Bool = false

    var id: String { ext }
}

// MARK: - Sort key

private enum SortKey {
    case ext, editor, handler, status
}

// MARK: - Extensions Tab

struct ExtensionsTab: View {

    @State private var rows: [ExtensionRow] = []
    @State private var editors: [EditorInfo] = []
    @State private var searchText = ""
    @State private var sortKey: SortKey = .status
    @State private var sortAscending = true
    @State private var showEditorPicker = false

    private var filteredRows: [ExtensionRow] {
        let base = searchText.isEmpty
            ? rows
            : rows.filter { $0.ext.localizedCaseInsensitiveContains(searchText) }
        return base.sorted(using: sortKey, ascending: sortAscending)
    }

    private var selectedCount: Int {
        rows.filter(\.isSelected).count
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if rows.isEmpty {
                Spacer()
                ProgressView("Querying handlers…")
                    .controlSize(.small)
                Spacer()
            } else {
                extensionList
                Divider()
                footer
            }
        }
        .task { await loadStatuses() }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            TextField("Filter extensions…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 220)

            Spacer()

            Button("Claim All") { claimAll() }
                .disabled(rows.allSatisfy { $0.status == .claimed || $0.status == .registered })
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Extension list

    private var extensionList: some View {
        List {
            // Header row
            HStack(spacing: 0) {
                Toggle("", isOn: selectAllBinding)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                    .frame(width: 32)

                columnHeader("Extension", key: .ext)
                    .frame(minWidth: 80, maxWidth: .infinity, alignment: .leading)
                columnHeader("Editor", key: .editor)
                    .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                columnHeader("Current Handler", key: .handler)
                    .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
                columnHeader("Status", key: .status)
                    .frame(minWidth: 80, maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .listRowSeparator(.visible, edges: .bottom)

            ForEach(filteredRows) { row in
                HStack(spacing: 0) {
                    Image(systemName: row.isSelected
                          ? "checkmark.square.fill" : "square")
                        .foregroundStyle(row.isSelected ? Color.accentColor : Color.secondary)
                        .imageScale(.large)
                        .frame(width: 32)

                    Text(".\(row.ext)")
                        .frame(minWidth: 80, maxWidth: .infinity, alignment: .leading)

                    editorCell(row)
                        .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)

                    Text(row.handlerName)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)

                    statusBadge(row.status)
                        .frame(minWidth: 80, maxWidth: .infinity, alignment: .leading)
                }
                .font(.body)
                .contentShape(Rectangle())
                .onTapGesture {
                    if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                        rows[idx].isSelected.toggle()
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Editor cell

    @ViewBuilder
    private func editorCell(_ row: ExtensionRow) -> some View {
        if row.hasOverride {
            Text(row.editorName)
                .foregroundStyle(.primary)
                .fontWeight(.bold)
        } else {
            Text("\(row.editorName) (default)")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("Selected: \(selectedCount)")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button("Set Editor…") { showEditorPicker = true }
                .disabled(selectedCount == 0)
                .popover(isPresented: $showEditorPicker) { editorPickerContent }

            Button("Clear Editor") { clearEditorForSelected() }
                .disabled(rows.filter { $0.isSelected && $0.hasOverride }.isEmpty)

            Spacer()

            Button("Claim Selected") { claimSelected() }
                .disabled(selectedCount == 0)

            Button("Release Selected") { releaseSelected() }
                .disabled(true)
                .help("Extension release is not yet implemented")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Editor picker popover

    private var editorPickerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Set editor for \(selectedCount) extension(s)")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(editors) { editor in
                        Button {
                            applyEditorToSelected(editor)
                            showEditorPicker = false
                        } label: {
                            HStack {
                                Image(nsImage: editor.icon)
                                    .resizable()
                                    .frame(width: 20, height: 20)
                                Text(editor.displayName)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    }
                }
            }
            .frame(maxHeight: 200)

            Divider()

            Button("Browse…") { browseForApp() }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(width: 240)
    }

    // MARK: - Column header

    private func columnHeader(_ title: String, key: SortKey) -> some View {
        Button {
            if sortKey == key {
                sortAscending.toggle()
            } else {
                sortKey = key
                sortAscending = true
            }
        } label: {
            HStack(spacing: 2) {
                Text(title)
                if sortKey == key {
                    Image(systemName: sortAscending
                          ? "chevron.up" : "chevron.down")
                        .imageScale(.small)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status badge

    private func statusBadge(_ status: HandlerStatus) -> some View {
        let (label, color): (String, Color) = switch status {
        case .registered: ("Registered", .blue)
        case .claimed:    ("Claimed",    .green)
        case .other:      ("Other",      .orange)
        case .unclaimed:  ("Unclaimed",  .gray)
        }

        return Text(label)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12), in: Capsule())
    }

    // MARK: - Bindings

    private var selectAllBinding: Binding<Bool> {
        let selectable = Set(filteredRows.map(\.id))
        return Binding(
            get: {
                !selectable.isEmpty && selectable.allSatisfy { id in
                    rows.first(where: { $0.id == id })?.isSelected == true
                }
            },
            set: { newValue in
                for id in selectable {
                    if let idx = rows.firstIndex(where: { $0.id == id }) {
                        rows[idx].isSelected = newValue
                    }
                }
            }
        )
    }

    // MARK: - Actions

    private func loadStatuses() async {
        // Skip re-load on tab switch; claim actions refresh rows directly.
        guard rows.isEmpty else { return }

        editors = EditorDetector.detectInstalledEditors()

        // queryAllStatuses calls Launch Services synchronously for each
        // extension, so run off the main actor to keep the UI responsive.
        let statuses = await Task.detached {
            ExtensionRegistry.queryAllStatuses()
        }.value

        let config = ConfigStore.shared
        rows = statuses.map { item in
            let resolved = config.resolvedEditor(for: item.ext)
            let editorName = resolved?.displayName ?? "(none)"
            let hasOverride = config.editorOverrides[item.ext.lowercased()] != nil
            return ExtensionRow(
                ext: item.ext,
                handlerName: handlerDisplayName(item.status),
                status: item.status,
                editorName: editorName,
                hasOverride: hasOverride
            )
        }
    }

    /// Claims every unclaimed extension regardless of the current search
    /// filter.  This is intentional — the user expectation for "Claim All"
    /// is that *all* extensions are claimed, not just the visible subset.
    private func claimAll() {
        let exts = rows
            .filter { $0.status != .claimed && $0.status != .registered }
            .map(\.ext)
        guard !exts.isEmpty else { return }
        performClaim(exts)
    }

    private func claimSelected() {
        // Registered rows have disabled checkboxes, but filter defensively.
        let exts = rows
            .filter { $0.isSelected && $0.status != .registered }
            .map(\.ext)
        guard !exts.isEmpty else { return }
        performClaim(exts)
    }

    private func releaseSelected() {
        // Registered rows have disabled checkboxes, but filter defensively.
        let exts = rows
            .filter { $0.isSelected && $0.status != .registered }
            .map(\.ext)
        NSLog("[Trampoline] Release requested for: %@", exts.joined(separator: ", "))
    }

    private func performClaim(_ exts: [String]) {
        let selectedIDs = Set(rows.filter(\.isSelected).map(\.id))

        Task.detached {
            let results = ExtensionRegistry.claim(extensions: exts)
            let failed = results.filter { $0.result == .failed }
            if !failed.isEmpty {
                NSLog("Trampoline: failed to claim %d extension(s): %@",
                      failed.count,
                      failed.map { ".\($0.ext)" }.joined(separator: ", "))
            }

            let newStatuses = ExtensionRegistry.queryAllStatuses()

            await MainActor.run {
                // Update ConfigStore's claimed list to match GeneralTab behavior.
                let succeeded = results.filter { $0.result == .success }.map(\.ext)
                if !succeeded.isEmpty {
                    var current = Set(ConfigStore.shared.claimedExtensions)
                    for ext in succeeded { current.insert(ext) }
                    ConfigStore.shared.claimedExtensions = Array(current).sorted()
                }

                let config = ConfigStore.shared
                rows = newStatuses.map { item in
                    let resolved = config.resolvedEditor(for: item.ext)
                    let editorName = resolved?.displayName ?? "(none)"
                    let hasOverride = config.editorOverrides[item.ext.lowercased()] != nil
                    return ExtensionRow(
                        ext: item.ext,
                        handlerName: handlerDisplayName(item.status),
                        status: item.status,
                        editorName: editorName,
                        hasOverride: hasOverride,
                        isSelected: selectedIDs.contains(item.ext)
                    )
                }
            }
        }
    }

    // MARK: - Editor actions

    private func applyEditorToSelected(_ editor: EditorInfo) {
        let exts = rows.filter(\.isSelected).map(\.ext)
        guard !exts.isEmpty else { return }
        ConfigStore.shared.setOverride(
            for: exts,
            editorBundleID: editor.bundleID,
            displayName: editor.displayName)
        refreshEditorColumn()
    }

    private func clearEditorForSelected() {
        let selectedExts = rows.filter { $0.isSelected && $0.hasOverride }.map(\.ext)
        guard !selectedExts.isEmpty else { return }
        ConfigStore.shared.clearOverrides(for: selectedExts)
        refreshEditorColumn()
    }

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        guard let bundle = Bundle(url: url),
              let bundleID = bundle.bundleIdentifier else {
            NSLog("Trampoline: selected app has no bundle identifier: %@",
                  url.path(percentEncoded: false))
            showEditorPicker = false
            return
        }
        let displayName = bundle.infoDictionary?["CFBundleName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        let icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
        icon.size = NSSize(width: 32, height: 32)
        let info = EditorInfo(bundleID: bundleID, displayName: displayName,
                              shorthand: nil, appURL: url, icon: icon)
        applyEditorToSelected(info)
        showEditorPicker = false
    }

    /// Updates `editorName` and `hasOverride` for all rows without
    /// re-querying Launch Services statuses.
    private func refreshEditorColumn() {
        let config = ConfigStore.shared
        for i in rows.indices {
            let ext = rows[i].ext
            let resolved = config.resolvedEditor(for: ext)
            rows[i].editorName = resolved?.displayName ?? "(none)"
            rows[i].hasOverride = config.editorOverrides[ext.lowercased()] != nil
        }
    }

    // MARK: - Helpers

    private func handlerDisplayName(_ status: HandlerStatus) -> String {
        switch status {
        case .registered:
            return "Trampoline (auto)"
        case .claimed:
            return "Trampoline"
        case .other(_, let displayName):
            return displayName
        case .unclaimed:
            return "(none)"
        }
    }
}

// MARK: - Sort helpers

private extension Array where Element == ExtensionRow {

    func sorted(using key: SortKey, ascending: Bool) -> [ExtensionRow] {
        let result: [ExtensionRow] = switch key {
        case .ext:
            self.sorted { $0.ext.localizedCaseInsensitiveCompare($1.ext) == .orderedAscending }
        case .editor:
            self.sorted { $0.editorName.localizedCaseInsensitiveCompare($1.editorName) == .orderedAscending }
        case .handler:
            self.sorted { $0.handlerName.localizedCaseInsensitiveCompare($1.handlerName) == .orderedAscending }
        case .status:
            self.sorted { statusPriority($0.status) < statusPriority($1.status) }
        }
        return ascending ? result : result.reversed()
    }
}

private func statusPriority(_ status: HandlerStatus) -> Int {
    switch status {
    case .other:      return 0
    case .unclaimed:  return 1
    case .claimed:    return 2
    case .registered: return 3
    }
}
