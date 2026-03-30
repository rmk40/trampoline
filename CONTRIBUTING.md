# Contributing to Trampoline

## Architecture

Trampoline is a macOS menu bar agent (`LSUIElement`) built with
`swiftc` and AppKit (no SPM, no Xcode project). The app has three
modes:

- **Menu bar mode** -- default. Sits in the menu bar, forwards files.
- **File forwarding** -- macOS sends open events via
  `application(_:open:)`, which delegates to `FileForwarder`.
- **CLI mode** -- detected when `argv[1]` is a known subcommand.
  Runs `CLIHandler.run()` and exits.

### How File Forwarding Works

1. `Info.plist` declares `CFBundleDocumentTypes` for 85 extensions.
   For custom UTIs (`dev.devfiletypes.*`), Trampoline uses
   `LSHandlerRank = Owner` (exported) or `Default` (imported).
   For system UTIs (`public.json`, etc.), it uses `Alternate`.
2. When a file is double-clicked, macOS routes it to Trampoline via
   `NSApplicationDelegate.application(_:open:)`.
3. `FileForwarder` resolves the editor for each file's extension via
   `ConfigStore.resolvedEditor(for:)` (checks per-extension overrides
   first, then the global default).
4. Files are grouped by resolved editor and opened via
   `NSWorkspace.shared.open(_:withApplicationAt:configuration:)` --
   one call per distinct editor.

### The 60/25 Split

- **60 extensions** have custom UTIs declared by Trampoline. macOS
  silently makes Trampoline the handler when `lsregister -f` runs.
  No API call needed, no confirmation dialog.
- **25 extensions** have system or dynamic UTIs already claimed by
  another app. Claiming these requires
  `LSSetDefaultRoleHandlerForContentType`, which triggers a macOS
  confirmation dialog per extension on macOS 12+.

### DRY Invariants

These rules are enforced by the DRY verification checklist and code
reviews:

| Invariant                                                        | Location                                |
| ---------------------------------------------------------------- | --------------------------------------- |
| All LaunchServices API calls (`LSCopyDefault*`, `LSSetDefault*`) | `ExtensionRegistry.swift` only          |
| All editor bundle ID data                                        | `EditorShorthands.swift` only           |
| All editor resolution logic (override -> global -> nil)          | `ConfigStore.resolvedEditor(for:)` only |
| No force-unwrapping (`as!`)                                      | Everywhere                              |
| No TODO/FIXME in committed code                                  | Everywhere                              |

### Source Files

| File                      | Purpose                                             |
| ------------------------- | --------------------------------------------------- |
| `TrampolineApp.swift`     | Entry point, `AppDelegate`, main menu               |
| `ConfigStore.swift`       | `@Observable` UserDefaults wrapper, editor resolver |
| `FileForwarder.swift`     | Groups URLs by editor, opens via NSWorkspace        |
| `CLIHandler.swift`        | CLI argument parser and dispatcher                  |
| `EditorShorthands.swift`  | Static registry of known editors                    |
| `ExtensionRegistry.swift` | 85 managed extensions, LS API wrapper               |
| `EditorDetector.swift`    | Scans for installed editors via NSWorkspace         |
| `SettingsWindow.swift`    | NSWindow + NSHostingController wrapper              |
| `GeneralTab.swift`        | Editor picker, claim buttons, status counts         |
| `ExtensionsTab.swift`     | Extension table, editor column, Set Editor popover  |
| `MenuBarManager.swift`    | NSStatusItem with NSMenuDelegate                    |
| `AboutTab.swift`          | Version info and links                              |
| `Info.plist`              | UTI declarations and CFBundleDocumentTypes          |

### Key APIs

- **`ConfigStore.resolvedEditor(for:)`** -- resolves an extension to
  `(bundleID, displayName)`. Checks `editorOverrides[ext]` first,
  falls back to `editorBundleID` (global default), returns nil if
  neither is set.
- **`ConfigStore.setOverride(for:editorBundleID:displayName:)`** --
  bulk-sets per-extension editor overrides.
- **`ExtensionRegistry.queryAllStatuses()`** -- queries
  `LSCopyDefaultRoleHandlerForContentType` for each of the 85
  extensions. Returns `HandlerStatus` (`.registered`, `.claimed`,
  `.other`, `.unclaimed`).
- **`ExtensionRegistry.claim(extensions:)`** -- calls
  `LSSetDefaultRoleHandlerForContentType` for `.alternate` rank
  extensions only. Skips `.primary` rank (plist-registered).
- **`EditorShorthands.resolve(_:)`** -- matches input against
  shorthand, bundle ID, or display name.

## Building

```sh
make all        # Compile
make clean      # Remove binary
make install    # Compile, copy to /Applications, codesign, lsregister, CLI symlink
make uninstall  # Remove app, symlink, preferences
```

The Makefile uses `swiftc -O -warnings-as-errors` and links AppKit,
CoreServices, and UniformTypeIdentifiers.

## DRY Verification

Run before submitting changes:

```bash
# LS API calls only in ExtensionRegistry
grep -rn "LSCopyDefault\|LSSetDefault" Sources/ | grep -v ExtensionRegistry

# Editor bundle IDs only in EditorShorthands
grep -rn "com\.microsoft\.VSCode\|dev\.zed\.Zed\|com\.sublimetext" Sources/ | grep -v EditorShorthands

# No force-unwrapping
grep -rn 'as!' Sources/*.swift

# No TODO/FIXME
grep -rn 'TODO\|FIXME\|HACK\|XXX' Sources/
```

Every check should produce zero output.

## Code Style

- Swift, strict mode, no `any` types
- No force-unwrapping -- use `guard let` / `if let`
- All errors logged via `NSLog`, never swallowed
- `@Observable` with stored properties + `didSet` for UserDefaults
- Conventional Commits for commit messages
