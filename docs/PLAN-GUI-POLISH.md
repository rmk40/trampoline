# GUI Polish & Custom Extensions Plan

**Version:** 1.0
**Date:** 2026-03-30
**Status:** Ready for execution
**Branch:** `main`
**Source:** User request (2026-03-30 session)
**Estimated total effort:** 3-5 hours (1-2 sessions)
**Dependencies:** swiftc, AppKit, SwiftUI, librsvg (rsvg-convert for icon)

---

## How to Use This Document

This plan is designed for execution by an **orchestrator agent** that
delegates implementation to specialized agents (`@code-writer`,
`@code-review`, `@docs-writer`) while maintaining full project context.

The orchestrator NEVER writes implementation code directly. Every line of
code is delegated. The orchestrator's job is to sequence work, provide
context, verify output, enforce quality gates, and maintain this plan.

### Orchestrator Workflow

For **every task**, follow this exact sequence:

```
1. DELEGATE  ->  @code-writer (with detailed prompt from this plan)
2. BUILD     ->  Verify: make clean && make all passes with zero warnings
3. TEST      ->  Smoke test the relevant functionality
4. LOOK      ->  (if UI changed) Visual verification
5. REVIEW    ->  @code-review-opus AND @code-review-gpt5 in parallel
6. FIX       ->  @code-writer (with specific review findings)
7. RE-REVIEW ->  (if fixes were substantial: >3 files or logic changes)
8. COMMIT    ->  Only after zero blockers from review
9. UPDATE    ->  Mark status table done, record commit SHA
```

### Authoritative References

| Document                          | Purpose                                     |
| --------------------------------- | ------------------------------------------- |
| `docs/PLAN.md`                    | Main implementation plan (Phases 1-5)       |
| `Sources/GeneralTab.swift`        | Current General tab implementation          |
| `Sources/AboutTab.swift`          | Current About tab implementation            |
| `Sources/SettingsWindow.swift`    | Window configuration (size, style)          |
| `Sources/ExtensionRegistry.swift` | Managed extension list (85 entries)         |
| `Sources/ConfigStore.swift`       | User preferences / UserDefaults persistence |

### Validation Commands

```bash
# Build (must pass before every commit)
make clean && make all

# Smoke test
make install && open /Applications/Trampoline.app
# Then: verify General tab, About tab, Extensions tab visually

# DRY checks
grep -rn 'LSSetDefaultRoleHandler\|LSCopyDefaultRoleHandler' Sources/ | grep -v ExtensionRegistry.swift
grep -rn 'TODO\|FIXME\|HACK\|XXX' Sources/
```

---

## Decision Log

| #   | Topic                     | Decision                                                                                                     | Rationale                                                                                                                                           |
| --- | ------------------------- | ------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | General tab scroll fix    | Increase default window height from 480→520 and minSize height from 400→440                                  | The General tab content overflows the current 480px height by a small margin, causing a scrollbar. A modest increase eliminates it without waste.   |
| 2   | About tab icon rendering  | Load SVG from bundle Resources, render via NSImage(contentsOfFile:) at 128x128. Fall back to app icon.       | The icns is generated from the SVG; rendering the SVG directly gives a crisp vector result at any size. 128x128 is standard for About-page icons.   |
| 3   | About tab icon bundling   | Copy SVG into Trampoline.app/Contents/Resources/ during build (Makefile change)                              | The SVG is already in the repo root. Bundling it lets the app load it at runtime without hardcoding a filesystem path.                              |
| 4   | Author attribution        | Add "Created by Rafi Khardalian" below the license line in the About tab                                     | User requested their name as author.                                                                                                                |
| 5   | GitHub URL                | Update AboutTab URLs from `maelos/trampoline` to `rmk40/trampoline`                                          | The actual repo is at `github.com/rmk40/trampoline`, not `maelos/trampoline`.                                                                       |
| 6   | Custom extension storage  | Store user-defined extensions in UserDefaults as `customExtensions: [String]` (lowercased, no dot prefix)    | Same pattern as `claimedExtensions`. Kept separate from the hardcoded 85 in ExtensionRegistry.                                                      |
| 7   | Custom extension handling | Custom extensions get rank `.alternate` and `uti = nil` (dynamic UTI resolution). They appear in status/GUI. | They can't have custom UTI plist declarations (that requires rebuilding Info.plist), but dynamic UTI resolution + LS claim works for any extension. |
| 8   | Custom extension parsing  | Accept comma, space, newline, or semicolon delimited input. Strip dots, whitespace, empty entries.           | User wants flexible paste-friendly input. The parser should be forgiving.                                                                           |
| 9   | Custom extension UI       | Add a "Custom Extensions" section to the Extensions tab with a TextEditor and "Add" button                   | Keeps it near the extension list where context is. Not in General tab (already crowded).                                                            |

---

## DRY Invariants

| #   | Invariant                          | Canonical location                 | Grep check                                                                                                                      |
| --- | ---------------------------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| 1   | All LaunchServices API calls       | `ExtensionRegistry.swift`          | `grep -rn 'LSSetDefaultRoleHandler\|LSCopyDefaultRoleHandler' Sources/ \| grep -v ExtensionRegistry.swift`                      |
| 2   | All editor bundle IDs (shorthands) | `EditorShorthands.swift`           | `grep -rn 'com\.microsoft\.VSCode\|dev\.zed\.Zed' Sources/ \| grep -v EditorShorthands.swift`                                   |
| 3   | All editor resolution logic        | `ConfigStore.resolvedEditor(for:)` | `grep -rn 'editorOverrides\[' Sources/ \| grep -v ConfigStore.swift \| grep -v ExtensionsTab.swift \| grep -v GeneralTab.swift` |
| 4   | No force-unwrapping                | Everywhere                         | `grep -rn '!' Sources/ \| grep -v '//' \| grep -v 'import' \| grep -v 'isEmpty' \| grep -v '@objc'`                             |
| 5   | No TODO/FIXME in committed code    | Everywhere                         | `grep -rn 'TODO\|FIXME\|HACK\|XXX' Sources/`                                                                                    |

---

## Execution Sequence

```
Phase 1: Window & About Polish
  GP-01 (General tab scroll)     -> build -> LOOK -> review -> commit
  GP-02 (About tab icon + author) -> build -> LOOK -> review -> commit

Phase 2: Custom Extensions
  GP-03 (ConfigStore + Registry)  -> build -> review -> commit
  GP-04 (CLI support)             -> build -> review -> commit
  GP-05 (Extensions tab UI)       -> build -> LOOK -> review -> commit
```

---

## Phases

### Phase 1: Window & About Polish

**Goal:** General tab displays without scrollbar. About tab has a large,
crisp app icon and author attribution. GitHub URLs are correct.

---

### GP-01: Fix General tab scrollbar

**Estimated effort:** 15 minutes
**Dependencies:** None
**Files:** `Sources/SettingsWindow.swift`

**Delegation prompt for `@code-writer`:**

> In the Trampoline macOS app, the Settings window's General tab content
> slightly overflows the window height, causing a scrollbar to appear.
>
> File: `/Users/rmk/projects/tools/trampoline/Sources/SettingsWindow.swift`
>
> Current window dimensions (line 24-26):
>
> ```swift
> window.setContentSize(NSSize(width: 640, height: 480))
> window.minSize = NSSize(width: 540, height: 400)
> window.maxSize = NSSize(width: 800, height: 600)
> ```
>
> Change the height values:
>
> - `setContentSize` height: 480 → 520
> - `minSize` height: 400 → 440
> - `maxSize` height: 600 → 640
>
> Do not change widths. Do not change anything else in the file.
>
> **Constraints:** Compiles with `swiftc -O -warnings-as-errors`. No
> force-unwrapping. No TODO/FIXME.

**Review criteria for `@code-review`:**

> Verify only the three height values changed. No other logic modified.
> Window still has `.titled, .closable, .miniaturizable` style mask
> (no `.resizable`). minSize < contentSize < maxSize for both dimensions.

**Acceptance criteria:**

- Build compiles with zero warnings
- General tab displays without scrollbar on default content (editor
  selected, extensions claimed, no overrides)
- Window is not excessively tall

**Status:**

| Step                        | Status  | Notes |
| --------------------------- | ------- | ----- |
| Delegate to @code-writer    | pending |       |
| Build verification          | pending |       |
| Smoke test                  | pending |       |
| Visual verification (if UI) | pending |       |
| Delegate to @code-review    | pending |       |
| Fix review findings         | pending |       |
| Commit                      | pending | SHA:  |
| Plan updated                | pending |       |

---

### GP-02: About tab icon, author, and URLs

**Estimated effort:** 30 minutes
**Dependencies:** None (can be done in parallel with GP-01)
**Files:** `Sources/AboutTab.swift`, `Makefile`

**Delegation prompt for `@code-writer`:**

> Update the About tab in Trampoline to show a larger app icon, add
> author attribution, and fix the GitHub URLs.
>
> File: `/Users/rmk/projects/tools/trampoline/Sources/AboutTab.swift`
>
> **Current state:**
>
> - Icon is 64x64 loaded from `NSApp.applicationIconImage`
> - No author name shown
> - GitHub URLs point to `maelos/trampoline` (wrong)
>
> **Changes required:**
>
> 1. **Icon size:** Change from 64x64 to 128x128. Update both the
>    `.frame(width: 64, height: 64)` on line 15 and the
>    `icon.size = NSSize(width: 64, height: 64)` on line 63.
>
>    Additionally, try to load the SVG from the app bundle first for
>    crisp rendering. The SVG will be at
>    `Bundle.main.path(forResource: "trampoline_app_icon", ofType: "svg")`.
>    Use `NSImage(contentsOfFile:)` to load it. If that fails (SVG not
>    bundled, or NSImage can't render it), fall back to the existing
>    `NSApp.applicationIconImage` approach.
>
>    The `appIcon` computed property should become:
>
>    ```swift
>    private var appIcon: NSImage {
>        // Prefer the bundled SVG for crisp vector rendering
>        if let svgPath = Bundle.main.path(
>            forResource: "trampoline_app_icon", ofType: "svg"),
>           let svgImage = NSImage(contentsOfFile: svgPath) {
>            svgImage.size = NSSize(width: 128, height: 128)
>            return svgImage
>        }
>        // Fallback: app icon from the bundle
>        let source = NSApp.applicationIconImage ?? NSImage(
>            named: NSImage.applicationIconName) ?? NSImage()
>        let icon = source.copy() as? NSImage ?? source
>        icon.size = NSSize(width: 128, height: 128)
>        return icon
>    }
>    ```
>
> 2. **Author:** Add "Created by Rafi Khardalian" below the "License: MIT"
>    line. Same font (`.footnote`) and color (`.secondary`).
> 3. **GitHub URLs:** Change both URLs:
>    - `https://github.com/maelos/trampoline` → `https://github.com/rmk40/trampoline`
>    - `https://github.com/maelos/trampoline/issues` → `https://github.com/rmk40/trampoline/issues`
>
> **Also update the Makefile** at
> `/Users/rmk/projects/tools/trampoline/Makefile` to copy the SVG into
> the app bundle during build. The Makefile currently has an `install`
> target that copies the app to `/Applications`. The `all` target builds
> the binary into `Trampoline.app/Contents/MacOS/Trampoline`.
>
> Add a line to the `all` target (or a prerequisite) that copies the SVG:
>
> ```
> cp trampoline_app_icon.svg Trampoline.app/Contents/Resources/
> ```
>
> This should run after the `mkdir -p` for Resources (if any) and before
> or after the `swiftc` compilation — order doesn't matter since it's
> a resource copy, not a compile dependency.
>
> Read the current Makefile first to understand its structure before
> making changes.
>
> **Constraints:** Compiles with `swiftc -O -warnings-as-errors`. No
> force-unwrapping. No TODO/FIXME. Do not change other tabs.

**Review criteria for `@code-review`:**

> - Icon loads from SVG with fallback — no crash if SVG is missing
> - No force-unwrapping in the icon loading path
> - Author name is exactly "Rafi Khardalian"
> - GitHub URLs point to `rmk40/trampoline`
> - Makefile copies SVG to correct bundle Resources path
> - No changes to other source files

**Acceptance criteria:**

- Build compiles with zero warnings
- About tab shows 128x128 app icon (crisp, not pixelated)
- "Created by Rafi Khardalian" appears below license
- GitHub links open correct repository
- SVG is present in built `Trampoline.app/Contents/Resources/`

**Status:**

| Step                        | Status  | Notes |
| --------------------------- | ------- | ----- |
| Delegate to @code-writer    | pending |       |
| Build verification          | pending |       |
| Smoke test                  | pending |       |
| Visual verification (if UI) | pending |       |
| Delegate to @code-review    | pending |       |
| Fix review findings         | pending |       |
| Commit                      | pending | SHA:  |
| Plan updated                | pending |       |

---

### Phase 2: Custom Extensions

**Goal:** Users can define additional file extensions beyond the hardcoded 85. Custom extensions are stored in UserDefaults, appear in the CLI
`status` output, appear in the Extensions tab, and participate in file
forwarding. They use dynamic UTI resolution (same as the existing 18
dynamic-UTI extensions like `.bash`, `.sql`, etc.).

---

### GP-03: Custom extension storage and registry integration

**Estimated effort:** 45 minutes
**Dependencies:** None
**Files:** `Sources/ConfigStore.swift`, `Sources/ExtensionRegistry.swift`

**Delegation prompt for `@code-writer`:**

> Add support for user-defined custom extensions to Trampoline.
>
> **ConfigStore changes** (`/Users/rmk/projects/tools/trampoline/Sources/ConfigStore.swift`):
>
> Add a new persisted property:
>
> ```swift
> var customExtensions: [String] = [] {
>     didSet { defaults.set(customExtensions, forKey: "customExtensions") }
> }
> ```
>
> Initialize it in `init()` alongside the other properties:
>
> ```swift
> self.customExtensions = defaults.stringArray(forKey: "customExtensions") ?? []
> ```
>
> Add a method to parse a freeform input string into extensions:
>
> ```swift
> /// Parses a freeform string of extensions into a cleaned array.
> /// Accepts comma, space, newline, or semicolon delimiters.
> /// Strips leading dots, whitespace, and empty entries.
> /// Returns lowercased extensions without duplicates, preserving order.
> static func parseExtensionInput(_ input: String) -> [String] {
>     let separators = CharacterSet(charactersIn: ",;\n\r ")
>     let raw = input.components(separatedBy: separators)
>     var seen = Set<String>()
>     var result = [String]()
>     for item in raw {
>         var ext = item.trimmingCharacters(in: .whitespaces)
>         if ext.hasPrefix(".") { ext = String(ext.dropFirst()) }
>         ext = ext.lowercased()
>         guard !ext.isEmpty, !seen.contains(ext) else { continue }
>         seen.insert(ext)
>         result.append(ext)
>     }
>     return result
> }
> ```
>
> Add convenience methods:
>
> ```swift
> /// Adds new custom extensions (deduplicating against existing).
> func addCustomExtensions(_ newExts: [String]) {
>     var current = Set(customExtensions)
>     var added = [String]()
>     for ext in newExts where !current.contains(ext) {
>         // Skip extensions already in the hardcoded registry
>         guard ExtensionRegistry.managedExtension(for: ext) == nil else { continue }
>         current.insert(ext)
>         added.append(ext)
>     }
>     if !added.isEmpty {
>         customExtensions = (customExtensions + added).sorted()
>     }
> }
>
> /// Removes custom extensions.
> func removeCustomExtensions(_ exts: [String]) {
>     let toRemove = Set(exts)
>     customExtensions = customExtensions.filter { !toRemove.contains($0) }
>     // Also clear any editor overrides for removed extensions
>     clearOverrides(for: exts)
> }
> ```
>
> **ExtensionRegistry changes** (`/Users/rmk/projects/tools/trampoline/Sources/ExtensionRegistry.swift`):
>
> The static `all` property currently returns a fixed array of 85
> `ManagedExtension` entries. Custom extensions need to be included in
> the list that `queryAllStatuses()`, `claim()`, and other methods
> iterate over.
>
> Add a computed property that combines hardcoded and custom extensions:
>
> ```swift
> /// All managed extensions including user-defined custom ones.
> /// Custom extensions use dynamic UTI resolution (uti = nil)
> /// and rank = .alternate (require explicit LS claim).
> static var allIncludingCustom: [ManagedExtension] {
>     let custom = ConfigStore.shared.customExtensions.compactMap { ext -> ManagedExtension? in
>         // Skip if already in the hardcoded list
>         guard !all.contains(where: { $0.ext == ext }) else { return nil }
>         return ManagedExtension(ext: ext, uti: nil, category: "Custom", rank: .alternate)
>     }
>     return all + custom
> }
> ```
>
> Then update `queryAllStatuses()` and `claim()` to use
> `allIncludingCustom` instead of `all`:
>
> - In `queryAllStatuses()` (line 246): change `all.map` to
>   `allIncludingCustom.map`
> - In `claim()` (line 289): change `managedExtension(for: ext)` lookup.
>   Actually, `claim()` uses `managedExtension(for:)` which searches
>   `all`. Add a parallel lookup method:
>   ```swift
>   /// Find extension in the combined list (hardcoded + custom).
>   static func anyManagedExtension(for ext: String) -> ManagedExtension? {
>       allIncludingCustom.first(where: { $0.ext == ext })
>   }
>   ```
>   Then in `claim()`, change the `managedExtension(for:)` call to
>   `anyManagedExtension(for:)`.
>
> Also update `plistRegistered` and `explicitOnly` to use
> `allIncludingCustom` so custom extensions appear in the correct
> filter results:
>
> - `plistRegistered`: keep using `all` (custom extensions are never
>   plist-registered — they don't have plist entries)
> - `explicitOnly`: change to `allIncludingCustom.filter { $0.rank == .alternate }`
>
> **Do NOT change** the static `all` property itself — it remains the
> hardcoded 85. The `allIncludingCustom` computed property layers custom
> extensions on top.
>
> **Constraints:** Compiles with `swiftc -O -warnings-as-errors`. No
> force-unwrapping. No TODO/FIXME. All LS API calls stay in
> ExtensionRegistry.swift.

**Review criteria for `@code-review`:**

> - `customExtensions` is persisted via UserDefaults with `didSet`
>   (same pattern as other ConfigStore properties)
> - `parseExtensionInput()` handles all delimiter types (comma, space,
>   newline, semicolon), strips dots, lowercases, deduplicates
> - `addCustomExtensions()` skips extensions already in the hardcoded
>   registry to prevent duplicates
> - `allIncludingCustom` doesn't duplicate hardcoded entries
> - `queryAllStatuses()` uses `allIncludingCustom`
> - `claim()` can find and claim custom extensions
> - `plistRegistered` still uses `all` (not `allIncludingCustom`)
> - No force-unwrapping, no TODO/FIXME

**Acceptance criteria:**

- Build compiles with zero warnings
- `ConfigStore.parseExtensionInput("vue, .svelte\nastro;zig")` returns
  `["astro", "svelte", "vue", "zig"]` (sorted, no dots)
- `addCustomExtensions(["xyz"])` adds it; adding `"rs"` (hardcoded)
  skips it
- `ExtensionRegistry.allIncludingCustom` includes custom extensions
- `queryAllStatuses()` returns entries for custom extensions

**Status:**

| Step                     | Status  | Notes |
| ------------------------ | ------- | ----- |
| Delegate to @code-writer | pending |       |
| Build verification       | pending |       |
| Smoke test               | pending |       |
| Delegate to @code-review | pending |       |
| Fix review findings      | pending |       |
| Commit                   | pending | SHA:  |
| Plan updated             | pending |       |

---

### GP-04: CLI support for custom extensions

**Estimated effort:** 30 minutes
**Dependencies:** GP-03
**Files:** `Sources/CLIHandler.swift`

**Delegation prompt for `@code-writer`:**

> Add CLI commands for managing custom extensions in Trampoline.
>
> File: `/Users/rmk/projects/tools/trampoline/Sources/CLIHandler.swift`
>
> **New subcommands:**
>
> 1. `trampoline extensions add <input>` — parse input string and add
>    custom extensions. Input can be comma/space/newline/semicolon
>    delimited. Print each added extension. Skip duplicates and
>    hardcoded extensions with a note.
> 2. `trampoline extensions remove <input>` — parse input string and
>    remove custom extensions. Print each removed extension. Silently
>    skip extensions not in the custom list.
> 3. `trampoline extensions list` — list all custom extensions, one per
>    line. Print "(none)" if empty.
> 4. `trampoline extensions clear` — remove all custom extensions.
>    Print count removed.
>
> **Integration with existing commands:**
>
> - `trampoline status` should already pick up custom extensions because
>   GP-03 changes `queryAllStatuses()` to use `allIncludingCustom`. But
>   verify that the status output includes them. Custom extensions should
>   appear in the UNCLAIMED or CLAIMED sections (never REGISTERED, since
>   they have no plist entries).
> - `trampoline status --json` should include custom extensions in the
>   output with an additional `"custom": true` field so consumers can
>   distinguish them.
>
> **Implementation approach:**
>
> Add `"extensions"` to the `subcommands` set. Add a `handleExtensions()`
> method that dispatches based on `args[2]` (`add`, `remove`, `list`,
> `clear`).
>
> Use `ConfigStore.parseExtensionInput()` for parsing the input in `add`
> and `remove`. The input string is everything from `args[3...]` joined
> by spaces (so `trampoline extensions add vue svelte astro` works, as
> does `trampoline extensions add "vue, svelte, astro"`).
>
> Read the current CLIHandler.swift to understand the existing pattern
> for subcommand dispatch (the `run()` method and `handleXxx()` methods).
>
> **Constraints:** Compiles with `swiftc -O -warnings-as-errors`. No
> force-unwrapping. No TODO/FIXME. Follow existing CLIHandler patterns.

**Review criteria for `@code-review`:**

> - `extensions` is added to the `subcommands` set
> - `add` parses flexible input (commas, spaces, etc.)
> - `add` rejects extensions already in the hardcoded 85
> - `remove` only removes from custom list, never from hardcoded
> - `list` and `clear` work correctly
> - `status --json` includes `"custom": true` for custom extensions
> - `--help` output is updated to mention the new commands
> - Exit codes follow existing patterns (0 success, 1 failure)

**Acceptance criteria:**

- Build compiles with zero warnings
- `trampoline extensions add "xyz, abc"` adds both, prints confirmation
- `trampoline extensions add rs` prints note that it's already managed
- `trampoline extensions list` shows added extensions
- `trampoline extensions remove xyz` removes it
- `trampoline extensions clear` removes all
- `trampoline status` shows custom extensions in output
- `trampoline status --json` includes `"custom": true` field

**Status:**

| Step                     | Status  | Notes |
| ------------------------ | ------- | ----- |
| Delegate to @code-writer | pending |       |
| Build verification       | pending |       |
| Smoke test               | pending |       |
| Delegate to @code-review | pending |       |
| Fix review findings      | pending |       |
| Commit                   | pending | SHA:  |
| Plan updated             | pending |       |

---

### GP-05: Custom extensions UI in Extensions tab

**Estimated effort:** 45 minutes
**Dependencies:** GP-03
**Files:** `Sources/ExtensionsTab.swift`

**Delegation prompt for `@code-writer`:**

> Add a "Custom Extensions" section to the Extensions tab in Trampoline's
> settings window.
>
> File: `/Users/rmk/projects/tools/trampoline/Sources/ExtensionsTab.swift`
>
> **Design:**
>
> Add a section below the extension list (above or below the existing
> toolbar/list, but visually distinct). The section should contain:
>
> 1. A `TextEditor` (or `TextField` with `.axis(.vertical)` for
>    multi-line) where the user can paste or type extensions. Placeholder
>    text: "Add extensions (e.g., vue, svelte, astro)"
> 2. An "Add" button that:
>    - Reads the text field content
>    - Calls `ConfigStore.parseExtensionInput()` to parse
>    - Calls `ConfigStore.shared.addCustomExtensions()` to store
>    - Clears the text field
>    - Reloads the extension list (call `loadStatuses()` or equivalent
>      — note that GP-03 makes `queryAllStatuses()` include custom
>      extensions, so reloading will pick them up)
>    - Shows a brief confirmation (e.g., "Added 3 extension(s)")
> 3. If custom extensions exist, show a label like
>    "N custom extension(s)" with a "Clear All" button to remove them.
>
> **Layout approach:**
>
> The Extensions tab currently has this structure:
>
> ```
> VStack {
>     toolbar (search, sort, claim buttons)
>     Divider()
>     if rows.isEmpty { spinner } else { extensionList }
> }
> ```
>
> Add the custom extensions section as a compact area below the toolbar
> and above the Divider. Use an `HStack` to keep it compact:
>
> ```
> HStack {
>     TextField("Add extensions...", text: $customInput, axis: .vertical)
>         .lineLimit(1...3)
>         .textFieldStyle(.roundedBorder)
>     Button("Add") { ... }
>         .disabled(customInput.trimmingCharacters(in: .whitespaces).isEmpty)
>     if !ConfigStore.shared.customExtensions.isEmpty {
>         Text("\(ConfigStore.shared.customExtensions.count) custom")
>             .font(.caption)
>             .foregroundStyle(.secondary)
>         Button("Clear All") { ... }
>             .font(.caption)
>     }
> }
> .padding(.horizontal)
> ```
>
> **State:**
>
> Add `@State private var customInput = ""` and
> `@State private var customMessage: String?` for feedback.
>
> **After adding/clearing:** The `rows` array must be refreshed. Currently
> `loadStatuses()` has a `guard rows.isEmpty else { return }` that
> prevents re-loading. You need to either:
>
> - Clear `rows` before calling `loadStatuses()` to force a refresh, OR
> - Extract the loading logic into a separate `reloadStatuses()` that
>   doesn't have the guard, and call that from both `loadStatuses()`
>   (first load) and the add/clear actions.
>
> The second approach is cleaner. Rename the body of `loadStatuses()`
> to `reloadStatuses()`, have `loadStatuses()` call
> `guard rows.isEmpty else { return }; await reloadStatuses()`, and
> have the add/clear actions call `Task { await reloadStatuses() }`.
>
> Read the current ExtensionsTab.swift to understand the existing
> structure before making changes.
>
> **Constraints:** Compiles with `swiftc -O -warnings-as-errors`. No
> force-unwrapping. No TODO/FIXME.

**Review criteria for `@code-review`:**

> - TextEditor/TextField accepts freeform input
> - "Add" button is disabled when input is empty/whitespace
> - Adding extensions reloads the row list (custom extensions appear)
> - "Clear All" removes custom extensions and reloads
> - No interference with existing extension list functionality
>   (selection, claiming, sorting, filtering, editor assignment)
> - The `loadStatuses()` guard for tab-switch flicker prevention
>   still works (first load shows spinner, re-visits don't flicker)
> - No force-unwrapping, no TODO/FIXME

**Acceptance criteria:**

- Build compiles with zero warnings
- Typing "xyz, abc" and clicking "Add" adds both extensions to the list
- Custom extensions appear in the extension table with status UNCLAIMED
- "Clear All" removes them from the list
- Existing extension list functionality (select, claim, sort, search,
  editor assignment) works unchanged
- Tab switch does NOT cause flicker (the guard still works)

**Status:**

| Step                        | Status  | Notes |
| --------------------------- | ------- | ----- |
| Delegate to @code-writer    | pending |       |
| Build verification          | pending |       |
| Smoke test                  | pending |       |
| Visual verification (if UI) | pending |       |
| Delegate to @code-review    | pending |       |
| Fix review findings         | pending |       |
| Commit                      | pending | SHA:  |
| Plan updated                | pending |       |

---

## Commit Protocol

**Format:** Conventional Commits

| Task  | Commit Message                                                   |
| ----- | ---------------------------------------------------------------- |
| GP-01 | `fix(gui): increase settings window height to prevent scrollbar` |
| GP-02 | `feat(about): larger SVG icon, author attribution, fix URLs`     |
| GP-03 | `feat(core): custom extension storage and registry integration`  |
| GP-04 | `feat(cli): extensions add/remove/list/clear commands`           |
| GP-05 | `feat(gui): custom extensions input in Extensions tab`           |

---

## File Impact Summary

| File                              | Task(s) | Purpose                                           |
| --------------------------------- | ------- | ------------------------------------------------- |
| `Sources/SettingsWindow.swift`    | GP-01   | Window height increase                            |
| `Sources/AboutTab.swift`          | GP-02   | Icon size, SVG loading, author, URLs              |
| `Makefile`                        | GP-02   | Copy SVG to bundle Resources                      |
| `Sources/ConfigStore.swift`       | GP-03   | customExtensions property, parseExtensionInput()  |
| `Sources/ExtensionRegistry.swift` | GP-03   | allIncludingCustom, anyManagedExtension(for:)     |
| `Sources/CLIHandler.swift`        | GP-04   | extensions subcommand (add/remove/list/clear)     |
| `Sources/ExtensionsTab.swift`     | GP-05   | Custom extension input UI, reload after add/clear |

---

## Risk Register

| Risk                                                    | Likelihood | Impact | Mitigation                                                                 |
| ------------------------------------------------------- | ---------- | ------ | -------------------------------------------------------------------------- |
| NSImage(contentsOfFile:) can't render SVG on some macOS | Low        | Low    | Fallback to icns-based app icon (already implemented in current code)      |
| Custom extensions with unknown UTIs fail to claim       | Medium     | Low    | Dynamic UTI resolution handles most extensions; claim failure is non-fatal |
| Window height increase not enough for some content      | Low        | Low    | The increase is based on actual content measurement; can adjust further    |

---

## Out of Scope

| Item                                 | Rationale                                                |
| ------------------------------------ | -------------------------------------------------------- |
| Custom UTI plist declarations        | Requires rebuilding Info.plist at runtime — not feasible |
| Per-extension editor routing via GUI | Already exists (Phase 5) — not part of this polish pass  |
| Project-aware routing                | Future feature, separate plan                            |
| Homebrew cask publication            | Deferred, not a polish item                              |

---

## Post-Completion Checklist

- [ ] `make clean && make all` builds cleanly on a fresh checkout
- [ ] All smoke tests pass
- [ ] DRY verification checklist passes (all invariants hold)
- [ ] No TODO/FIXME comments in source
- [ ] `@code-review` returns zero blockers on final codebase
- [ ] All status tables in this plan are marked done with commit SHAs
- [ ] General tab has no scrollbar
- [ ] About tab shows 128x128 crisp icon and author name
- [ ] Custom extensions can be added via CLI and GUI
- [ ] Custom extensions appear in status output and extension list
