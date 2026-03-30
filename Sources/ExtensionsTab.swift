import SwiftUI

// MARK: - Row model

private struct ExtensionRow: Identifiable {
    let ext: String
    var handlerName: String
    var status: HandlerStatus
    var isSelected: Bool = false

    var id: String { ext }
}

// MARK: - Sort key

private enum SortKey {
    case ext, handler, status
}

// MARK: - Extensions Tab

struct ExtensionsTab: View {

    @State private var rows: [ExtensionRow] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var sortKey: SortKey = .status
    @State private var sortAscending = true

    private var filteredRows: [ExtensionRow] {
        let base = searchText.isEmpty
            ? rows
            : rows.filter { $0.ext.localizedCaseInsensitiveContains(searchText) }
        return base.sorted(using: sortKey, ascending: sortAscending)
    }

    private var selectedCount: Int {
        rows.filter { $0.isSelected && $0.status != .registered }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if isLoading {
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
                columnHeader("Current Handler", key: .handler)
                    .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)
                columnHeader("Status", key: .status)
                    .frame(minWidth: 80, maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .listRowSeparator(.visible, edges: .bottom)

            ForEach(filteredRows) { row in
                let isRegistered = row.status == .registered
                HStack(spacing: 0) {
                    Toggle("", isOn: binding(for: row.id))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .disabled(isRegistered)
                        .frame(width: 32)

                    Text(".\(row.ext)")
                        .frame(minWidth: 80, maxWidth: .infinity, alignment: .leading)

                    Text(row.handlerName)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 120, maxWidth: .infinity, alignment: .leading)

                    statusBadge(row.status)
                        .frame(minWidth: 80, maxWidth: .infinity, alignment: .leading)
                }
                .font(.body)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("Selected: \(selectedCount)")
                .font(.callout)
                .foregroundStyle(.secondary)

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

    private func binding(for id: String) -> Binding<Bool> {
        Binding(
            get: { rows.first(where: { $0.id == id })?.isSelected ?? false },
            set: { newValue in
                guard let idx = rows.firstIndex(where: { $0.id == id }) else { return }
                guard rows[idx].status != .registered else { return }
                rows[idx].isSelected = newValue
            }
        )
    }

    private var selectAllBinding: Binding<Bool> {
        // Only non-registered rows are selectable — registered extensions
        // are plist-managed and can't be claimed or released.
        let selectable = Set(
            filteredRows
                .filter { $0.status != .registered }
                .map(\.id)
        )
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
        isLoading = true
        // queryAllStatuses calls Launch Services synchronously for each
        // extension, so run off the main actor to keep the UI responsive.
        let statuses = await Task.detached {
            ExtensionRegistry.queryAllStatuses()
        }.value

        rows = statuses.map { item in
            ExtensionRow(
                ext: item.ext,
                handlerName: handlerDisplayName(item.status),
                status: item.status
            )
        }
        isLoading = false
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
        isLoading = true
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

                rows = newStatuses.map { item in
                    ExtensionRow(
                        ext: item.ext,
                        handlerName: handlerDisplayName(item.status),
                        status: item.status,
                        isSelected: selectedIDs.contains(item.ext)
                    )
                }
                isLoading = false
            }
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
