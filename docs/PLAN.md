# Trampoline Implementation Plan

**Version:** 1.1
**Date:** 2026-03-29
**Status:** Planning
**Branch:** `main`
**Source:** Design specification (`docs/00-overview.md` through `docs/06-phases.md`)
**Estimated total effort:** 12-18 hours (6-9 sessions)
**Dependencies:** Xcode CLT (swiftc), macOS 14+

---

## How to Use This Document

This plan implements the Trampoline macOS app as specified in the design
documents. It is designed for execution by an **orchestrator agent** (you) who
delegates implementation work to specialized agents (`@code-writer`,
`@code-review`, `@docs-writer`) while maintaining full project context
throughout execution.

### Orchestrator Role

The orchestrator **never writes implementation code directly**. Instead:

1. **Read** the design docs and this plan to build full project context
2. **Delegate** implementation to `@code-writer` with detailed prompts that
   include all necessary context from this plan and the design docs
3. **Verify** the output (build, smoke test, LOOK checkpoints)
4. **Delegate review** to `@code-review` — **EVERY task gets a review before
   commit, no exceptions**. Even "simple" tasks like TR-01 and TR-02 need
   review (the TR-02 review caught a blocker in the uninstall target).
5. **Fix** issues by delegating back to `@code-writer` with specific findings
6. **Re-review** if fixes were substantial (>3 files changed or logic altered)
7. **Commit** only after all validation gates pass AND review returns zero
   blockers
8. **Update this plan** immediately after each step completes

### Context Window Strategy

This project is designed for execution within a **1M token context window**.
The orchestrator should:

- **Load all design docs at session start** — read `docs/00-overview.md`
  through `docs/06-phases.md` plus this plan before delegating any work.
  These total ~3,500 lines and establish the full mental model.
- **Never compact mid-project** — the `-> COMPACT` markers from earlier plan
  versions are removed. The orchestrator retains full context across all
  phases to catch cross-cutting concerns and ensure consistency.
- **Include relevant context in every delegation prompt** — when delegating
  to `@code-writer`, include the specific design doc sections, wireframes,
  data model tables, and flow diagrams needed for that task. The delegated
  agent has no prior context; everything it needs must be in the prompt.
- **Track cumulative state** — as each task completes, the orchestrator
  carries knowledge of what was built forward. Later tasks reference earlier
  implementations (e.g., TR-07 uses `ExtensionRegistry` from TR-04).
  The orchestrator must include file paths and API signatures from prior
  tasks in delegation prompts for dependent tasks.

### Resuming Mid-Plan

An agent resuming mid-plan should:

1. Read this entire document
2. Read all design docs (`docs/00-overview.md` through `docs/06-phases.md`)
3. Check the **per-task status tables** for the first incomplete step
4. Run `git log --oneline -20` and `git status` to orient
5. Read the source files created by completed tasks to rebuild context
6. Resume from the first incomplete step

### Authoritative References

| Document                  | Purpose                                                                   |
| ------------------------- | ------------------------------------------------------------------------- |
| `docs/00-overview.md`     | Problem statement, solution, prior art                                    |
| `docs/01-architecture.md` | Components, lifecycle, tech stack, DRY principles, open source references |
| `docs/02-use-cases.md`    | All use cases (UC-1 through UC-10)                                        |
| `docs/03-flows.md`        | Sequence/flow diagrams for every operation                                |
| `docs/04-wireframes.md`   | Screen designs for GUI and CLI                                            |
| `docs/05-data-model.md`   | Config schema, Info.plist structure, extension registry                   |
| `docs/06-phases.md`       | Phase plan and decision log                                               |

### Validation Commands

```bash
# Full build (must pass before every commit)
make clean && make all

# Verify binary
file Trampoline.app/Contents/MacOS/Trampoline

# Smoke test: CLI mode
./Trampoline.app/Contents/MacOS/Trampoline --help

# Smoke test: file forwarding
cp -R Trampoline.app /Applications/
trampoline editor zed
open -a Trampoline test-file.rs
```

---

## Plan Maintenance Protocol

This document is a living artifact. The orchestrator must keep it accurate:

1. **Status tables** — update the status column of each step **immediately**
   after completing it (not in batches). Valid states: `pending`,
   `in progress`, `done`, `blocked`, `skipped`.
2. **Notes column** — record deviations, surprises, review findings, or
   anything a resuming agent needs. Include:
   - Commit SHA after committing (e.g., `a1b2c3d`)
   - Review outcomes (e.g., "2 issues found, fixed")
   - Design deviations (e.g., "used ObservableObject instead of @Observable")
3. **Commits** — every task produces at least one commit. See
   [Commit Protocol](#commit-protocol).
4. **Decision log** — if a task reveals a needed design decision not already
   recorded, add a row before implementing.
5. **Plan version** — bump the Version field when making structural changes.

---

## Decision Log

| #   | Topic                            | Decision                                                | Rationale                                                                                         |
| --- | -------------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| 1   | Build system                     | Makefile + swiftc (not SPM)                             | Zero dependencies, mirrors DevFileTypes pattern, simpler for a single-binary app                  |
| 2   | App entry point                  | `@main` struct + `NSApplicationDelegate`                | Required for `application(_:open:)` file events; SwiftUI `App` protocol can't receive these       |
| 3   | CLI detection                    | Check `argv[0]` basename and subcommand presence        | Same binary serves GUI and CLI; symlink at `/usr/local/bin/trampoline`                            |
| 4   | UTI declarations                 | Carry over from DevFileTypes Info.plist                 | Proven declarations, avoid duplication of effort                                                  |
| 5   | CFBundleDocumentTypes generation | Hand-authored in Info.plist                             | 84 extensions is manageable; generated plist adds build complexity                                |
| 6   | Config storage                   | UserDefaults (standard domain)                          | Simple, CLI-accessible via `defaults`, no file management                                         |
| 7   | Editor detection                 | mdfind + NSWorkspace                                    | No permissions needed, system-native                                                              |
| 8   | Minimum macOS                    | 14.0 (Sonoma)                                           | SwiftUI maturity, modern UTType APIs                                                              |
| 9   | No tests in Phase 1              | Manual smoke testing sufficient                         | CLI + GUI are thin wrappers over system APIs; add tests if complexity grows                       |
| 10  | Single extension registry        | `ExtensionRegistry.swift` is the sole source of truth   | DRY: Info.plist, CLI status, and GUI Extensions tab all derive from this one list                 |
| 11  | Single editor registry           | `EditorShorthands.swift` is the sole source of truth    | DRY: CLI resolution, EditorDetector scan, and GUI picker all consume this one registry            |
| 12  | Shared LS API wrapper            | All LaunchServices calls go through `ExtensionRegistry` | Prevents inconsistent UTI handling — the exact bug class that corrupted the plist in DevFileTypes |

---

## Execution Sequence

```
Phase 1: Foundation (4 tasks, ~6 hours)
  TR-01 (project skeleton + build system)
    -> commit: chore(build)
  TR-02 (Info.plist: UTIs + CFBundleDocumentTypes)
    -> commit: feat(plist)
  TR-03 (ConfigStore + FileForwarder + AppDelegate)
    -> review -> commit: feat(core)
  TR-04 (CLI handler + shared registries)
    -> review -> commit: feat(cli)
  -> VERIFY: build, install, CLI smoke test, file forwarding
  -> DO NOT COMPACT — carry full context forward

Phase 2: GUI (4 tasks, ~5 hours)
  TR-05 (EditorDetector)
    -> commit: feat(core)
  TR-06 (Settings window: General tab)
    -> LOOK -> review -> commit: feat(gui)
  TR-07 (Settings window: Extensions tab)
    -> LOOK -> review -> commit: feat(gui)
  TR-08 (Menu bar item + About tab)
    -> commit: feat(gui)
  -> VERIFY: full GUI walkthrough, first-run flow
  -> DO NOT COMPACT — carry full context forward

Phase 3: Polish (3 tasks, ~3 hours)
  TR-09 (First-run + error recovery flows)
    -> review -> commit: feat(core)
  TR-10 (Install script + Homebrew prep)
    -> commit: chore(build)
  TR-11 (README + final review)
    -> review -> commit: docs
  -> VERIFY: clean-machine install, full end-to-end test
```

---

## Task Definitions

### TR-01: Project Skeleton and Build System

**Estimated effort:** 1 session (1-2 hours)
**Dependencies:** None
**References:** `docs/01-architecture.md` (bundle structure, tech stack)

**Delegation prompt for `@code-writer`:**

> Create the project skeleton for a macOS app called "Trampoline"
> (bundle ID: `com.maelos.trampoline`) at the current working directory.
>
> Create these files:
>
> 1. **`Sources/TrampolineApp.swift`** — minimal stub that imports AppKit,
>    creates an NSApplication, sets a delegate, prints "Trampoline running"
>    to stdout, and calls `NSApplication.shared.run()`. The delegate class
>    should have an empty `applicationDidFinishLaunching` that just prints
>    the message. This will be rewritten in TR-03.
> 2. **`Makefile`** with these targets:
>    - `all`: compile all `.swift` files in `Sources/` into
>      `Trampoline.app/Contents/MacOS/Trampoline` using `swiftc -O`.
>      Link frameworks: AppKit, CoreServices, UniformTypeIdentifiers.
>      Use `-warnings-as-errors`.
>    - `clean`: remove `Trampoline.app/Contents/MacOS/Trampoline`
>    - `install`: copy `Trampoline.app` to `/Applications/`, run
>      `lsregister -f`, create symlink
>      `/usr/local/bin/trampoline -> /Applications/Trampoline.app/Contents/MacOS/Trampoline`
>    - `uninstall`: remove symlink, remove
>      `/Applications/Trampoline.app`
>      The `LSREGISTER` path is
>      `/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister`
> 3. **`.gitignore`** — ignore `Trampoline.app/Contents/MacOS/Trampoline`
>    (the compiled binary), `.DS_Store`, `*.o`, `*.swp`
> 4. **`Trampoline.app/Contents/MacOS/`** — create this directory (empty;
>    the binary goes here at build time)
> 5. **`Trampoline.app/Contents/Resources/`** — create this directory
>    (empty for now; icons go here later)
>
> Do NOT create Info.plist yet (that's TR-02).
> Verify the build works: `make clean && make all` should succeed.

**Scope:**

- [ ] Delegate to `@code-writer` with the above prompt
- [ ] Verify: `make clean && make all` produces valid Mach-O binary
- [ ] Verify: running the binary prints "Trampoline running"
- [ ] `git init && git add -A && git commit`
- [ ] Update this plan: mark steps done, record commit SHA

**Acceptance criteria:**

- `make all` compiles without errors or warnings
- `file Trampoline.app/Contents/MacOS/Trampoline` shows Mach-O executable
- Running the binary prints "Trampoline running"
- `.gitignore` excludes the compiled binary

**Status:**

| Step                     | Status | Notes                                 |
| ------------------------ | ------ | ------------------------------------- |
| Delegate to @code-writer | done   |                                       |
| Build verification       | done   |                                       |
| Binary smoke test        | done   |                                       |
| Delegate to @code-review | done   | Reviewed with TR-02; fixes in bbe3b55 |
| Commit                   | done   | 1b632aa                               |
| Plan updated             | done   |                                       |

---

### TR-02: Info.plist — UTIs and CFBundleDocumentTypes

**Estimated effort:** 1 session (1.5-2 hours)
**Dependencies:** TR-01
**References:** `docs/05-data-model.md` (full extension registry, LSHandlerRank strategy, UTI tables)

**Delegation prompt for `@code-writer`:**

> Create `Trampoline.app/Contents/Info.plist` for the Trampoline macOS app.
>
> This plist has three sections:
>
> **Section 1: App identity**
>
> - CFBundleIdentifier: `com.maelos.trampoline`
> - CFBundleName: `Trampoline`
> - CFBundleDisplayName: `Trampoline`
> - CFBundleExecutable: `Trampoline`
> - CFBundleVersion: `1.0`
> - CFBundleShortVersionString: `1.0`
> - CFBundlePackageType: `APPL`
> - LSMinimumSystemVersion: `14.0`
> - LSUIElement: `true` (menu bar agent, no Dock icon)
> - NSHighResolutionCapable: `true`
>
> **Section 2: UTI declarations** — copy the `UTExportedTypeDeclarations`
> (2 entries) and `UTImportedTypeDeclarations` (35 entries) verbatim from
> `/Users/rmk/projects/tools/DevFileTypes/DevFileTypes.app/Contents/Info.plist`.
>
> **Section 3: CFBundleDocumentTypes** — one entry per UTI or extension group.
>
> For custom UTIs (dev.devfiletypes.\*), use `LSHandlerRank = Default` and
> reference the UTI in `LSItemContentTypes`. Example:
>
> ```xml
> <dict>
>     <key>CFBundleTypeName</key>
>     <string>Rust Source</string>
>     <key>CFBundleTypeRole</key>
>     <string>Editor</string>
>     <key>LSHandlerRank</key>
>     <string>Default</string>
>     <key>LSItemContentTypes</key>
>     <array>
>         <string>dev.devfiletypes.rust-source</string>
>     </array>
> </dict>
> ```
>
> For system UTIs (public.json, public.python-script, etc.), use
> `LSHandlerRank = Alternate`:
>
> ```xml
> <dict>
>     <key>CFBundleTypeName</key>
>     <string>JSON Document</string>
>     <key>CFBundleTypeRole</key>
>     <string>Editor</string>
>     <key>LSHandlerRank</key>
>     <string>Alternate</string>
>     <key>LSItemContentTypes</key>
>     <array>
>         <string>public.json</string>
>     </array>
> </dict>
> ```
>
> For extensions with dynamic UTIs (.env, .conf, .tsv, .lock, .gitignore,
> .gitattributes, .editorconfig, .dockerfile, .makefile, .gemspec, .cmake,
> .gradle, .properties, .patch, .diff), use `CFBundleTypeExtensions` instead
> of `LSItemContentTypes`, with `LSHandlerRank = Alternate`.
>
> Refer to `docs/05-data-model.md` for the complete extension registry
> (tables "Extensions with Custom UTIs", "Extensions with System UTIs",
> "Extensions with Dynamic UTIs").
>
> Validate with `plutil -lint` when done.

**Scope:**

- [ ] Delegate to `@code-writer` with the above prompt
- [ ] Verify: `plutil -lint Trampoline.app/Contents/Info.plist` passes
- [ ] Verify: `make all` still builds
- [ ] Count: 37 UTI declarations (2 exported + 35 imported)
- [ ] Count: CFBundleDocumentTypes covers all 84 managed extensions
- [ ] Commit: `feat(plist): UTI declarations and CFBundleDocumentTypes`
- [ ] Update this plan

**Acceptance criteria:**

- `plutil -lint` passes with no errors
- 37 UTI declarations present
- CFBundleDocumentTypes covers all 84 managed extensions
- `make all` still builds

**Status:**

| Step                       | Status | Notes                                     |
| -------------------------- | ------ | ----------------------------------------- |
| Delegate to @code-writer   | done   |                                           |
| plutil validation          | done   |                                           |
| Build verification         | done   |                                           |
| UTI count verification     | done   | 2 exported + 41 imported                  |
| DocType count verification | done   | 57 entries covering 85 extensions         |
| Delegate to @code-review   | done   | 1 blocker, 4 issues, 4 nits               |
| Fix review findings        | done   | lsregister -u, mkdir -p, InfoDictVer, etc |
| Commit                     | done   | bbe3b55                                   |
| Plan updated               | done   |                                           |

---

### TR-03: ConfigStore, FileForwarder, and AppDelegate

**Estimated effort:** 1.5 sessions (2-3 hours)
**Dependencies:** TR-01, TR-02
**References:** `docs/01-architecture.md` (component responsibilities), `docs/03-flows.md` (F-02, F-10)

**Delegation prompt for `@code-writer`:**

> Create three Swift source files for the Trampoline macOS app. The project
> is at the current working directory. All Swift files go in `Sources/`.
>
> **Important DRY principle:** ConfigStore is the SINGLE source of truth for
> all configuration. Both GUI (future) and CLI will bind to it. Do NOT
> create parallel config mechanisms.
>
> **1. `Sources/ConfigStore.swift`**
>
> A UserDefaults-backed observable store for `com.maelos.trampoline`.
> Use the `@Observable` macro (macOS 14+).
>
> Properties (all persisted to UserDefaults):
>
> - `editorBundleID: String?` (default: nil)
> - `editorDisplayName: String?` (default: nil)
> - `showMenuBarIcon: Bool` (default: true)
> - `firstRunComplete: Bool` (default: false)
> - `claimedExtensions: [String]` (default: [])
>
> Include a `static let shared = ConfigStore()` singleton.
> Use computed properties that read/write UserDefaults.standard.
> Use KVO or didSet to keep the @Observable macro in sync with UserDefaults.
>
> **2. `Sources/FileForwarder.swift`**
>
> Receives file URLs and forwards them to the user's configured editor.
>
> ```swift
> enum ForwardResult {
>     case success
>     case noEditor          // editorBundleID is nil
>     case editorNotFound    // editor app not installed
>     case openFailed(Error) // NSWorkspace.open failed
> }
> ```
>
> - `var pendingFiles: [URL] = []` — stores files when forwarding fails
> - `func forward(urls: [URL]) -> ForwardResult` — reads
>   `ConfigStore.shared.editorBundleID`, resolves via
>   `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)`, opens via
>   `NSWorkspace.shared.open(_:withApplicationAt:configuration:)`.
>   On `.noEditor` or `.editorNotFound`, appends to `pendingFiles`.
> - `func retryPending() -> ForwardResult` — forwards `pendingFiles` then
>   clears the array on success.
>
> Reference: Finicky's AppDelegate handles URL events similarly — receive
> event, look up target app, forward via NSWorkspace.
>
> **3. `Sources/TrampolineApp.swift`** (rewrite the stub from TR-01)
>
> Entry point. Creates NSApplication, sets delegate, runs the app.
>
> The delegate implements:
>
> - `applicationDidFinishLaunching(_:)` — detect launch mode:
>   - If `CommandLine.arguments` contains a known subcommand (editor,
>     status, claim, install-cli, uninstall, --help, --version): set a flag
>     for CLI mode (will be handled in TR-04; for now, print
>     "CLI mode: not yet implemented" and exit)
>   - Otherwise: the app is in GUI/forward mode. For now, just log
>     "Trampoline ready" and stay running.
> - `application(_:open:)` — called by macOS when files are opened.
>   Delegate to `FileForwarder.shared.forward(urls:)`. Handle the result:
>   - `.success`: do nothing (file opened)
>   - `.noEditor`: log warning, will show settings in TR-06
>   - `.editorNotFound`: log warning, will show settings in TR-06
>   - `.openFailed`: log error
> - `applicationShouldTerminateAfterLastWindowClosed(_:)` — return `false`
> - `applicationShouldHandleReopen(_:hasVisibleWindows:)` — will show
>   settings window in TR-06; for now return `true`
>
> Use `FileForwarder.shared` singleton pattern (matches ConfigStore).
>
> After creating the files, verify: `make clean && make all` compiles.

**Scope:**

- [ ] Delegate to `@code-writer` with the above prompt
- [ ] Verify: `make clean && make all` compiles
- [ ] Smoke test: set editor via `defaults write`, install app, double-click
      a `.rs` file, verify Zed opens
- [ ] Delegate to `@code-review`: review all three files for correctness,
      error handling, macOS API usage, ForwardResult exhaustiveness
- [ ] Fix any review findings (delegate back to `@code-writer` if needed)
- [ ] Re-review if fixes were substantial
- [ ] Commit: `feat(core): ConfigStore, FileForwarder, and AppDelegate`
- [ ] Update this plan

**Acceptance criteria:**

- Double-clicking a file whose handler is Trampoline opens it in the configured editor
- Multiple files arrive as a batch in the editor
- App stays running after forwarding (visible in Activity Monitor)
- No editor configured -> stores files as pending, logs warning, does not crash
- No force-unwrapping anywhere (guard let / if let only)

**Status:**

| Step                       | Status | Notes                                              |
| -------------------------- | ------ | -------------------------------------------------- |
| Delegate to @code-writer   | done   |                                                    |
| Build verification         | done   |                                                    |
| File forwarding smoke test | done   | tested via --help stub                             |
| Delegate to @code-review   | done   | 1 blocker, 4 issues, 5 nits                        |
| Fix review findings        | done   | retry dup bug, @Observable, pendingFiles, delegate |
| Commit                     | done   | 254c3c4                                            |
| Plan updated               | done   |                                                    |

---

### TR-04: CLI Handler and Shared Registries

**Estimated effort:** 1.5 sessions (2-3 hours)
**Dependencies:** TR-03
**References:** `docs/04-wireframes.md` (CLI section), `docs/03-flows.md` (F-05), `docs/05-data-model.md` (editor + extension registries), `docs/01-architecture.md` (DRY principles, open source references)

**Delegation prompt for `@code-writer`:**

> Create three Swift source files for the Trampoline macOS app CLI and
> shared data registries. All files go in `Sources/`.
>
> **Critical DRY principle:** `ExtensionRegistry` is the SINGLE source of
> truth for all managed extensions. `EditorShorthands` is the SINGLE source
> of truth for known editors. All code paths (CLI, GUI, FileForwarder) must
> use these registries. Never hardcode an extension or editor bundle ID
> elsewhere.
>
> **1. `Sources/EditorShorthands.swift`**
>
> A static registry of known code editors.
>
> ```swift
> struct EditorEntry {
>     let shorthand: String
>     let bundleID: String
>     let displayName: String
> }
> ```
>
> Include all entries from this table:
>
> | shorthand       | bundleID                      | displayName        |
> | --------------- | ----------------------------- | ------------------ |
> | zed             | dev.zed.Zed                   | Zed                |
> | vscode          | com.microsoft.VSCode          | Visual Studio Code |
> | vscode-insiders | com.microsoft.VSCodeInsiders  | VS Code Insiders   |
> | cursor          | com.todesktop.230313mzl4w4u92 | Cursor             |
> | sublime         | com.sublimetext.4             | Sublime Text       |
> | sublime3        | com.sublimetext.3             | Sublime Text 3     |
> | nova            | com.panic.Nova                | Nova               |
> | bbedit          | com.barebones.bbedit          | BBEdit             |
> | textmate        | com.macromates.TextMate       | TextMate           |
> | webstorm        | com.jetbrains.WebStorm        | WebStorm           |
> | intellij        | com.jetbrains.intellij        | IntelliJ IDEA      |
> | fleet           | com.jetbrains.fleet           | Fleet              |
>
> Provide:
>
> - `static let all: [EditorEntry]`
> - `static func resolve(_ input: String) -> EditorEntry?` — match by
>   shorthand (case-insensitive), then by bundleID (exact), then by
>   displayName (case-insensitive). Return nil if no match.
> - `static func isKnownEditor(_ bundleID: String) -> Bool` — true if the
>   bundleID is in the registry or starts with `com.jetbrains.`
>
> Reference: DevFileTypes `set-default-editor.sh` lines 47-75 for the
> original editor list (ported from bash to Swift here).
>
> **2. `Sources/ExtensionRegistry.swift`**
>
> The single source of truth for all managed extensions and their LS API
> interactions.
>
> ```swift
> enum HandlerRank { case primary, alternate }
> enum HandlerStatus { case claimed, other(String), unclaimed }
>
> struct ManagedExtension {
>     let ext: String         // e.g., "rs"
>     let uti: String?        // e.g., "dev.devfiletypes.rust-source" or nil for dynamic
>     let category: String    // e.g., "Systems", "Web frameworks"
>     let rank: HandlerRank   // Default vs Alternate in Info.plist
> }
> ```
>
> Include ALL 84 extensions from docs/05-data-model.md tables
> ("Extensions with Custom UTIs", "Extensions with System UTIs",
> "Extensions with Dynamic UTIs"). The `uti` field is nil for dynamic-UTI
> extensions (resolved at runtime via `UTType(filenameExtension:)`).
>
> Provide:
>
> - `static let all: [ManagedExtension]`
> - `static func queryHandler(for ext: String) -> (bundleID: String, displayName: String)?`
>   — resolves extension to UTI (via stored `uti` or
>   `UTType(filenameExtension:)`), calls
>   `LSCopyDefaultRoleHandlerForContentType`, resolves display name via
>   `NSWorkspace`. This is the ONLY place in the codebase that calls
>   LSCopyDefaultRoleHandlerForContentType.
> - `static func queryAllStatuses() -> [(ext: String, status: HandlerStatus)]`
>   — calls `queryHandler` for each extension, categorizes as claimed
>   (handler is `com.maelos.trampoline`), other, or unclaimed.
> - `static func claim(extensions: [String]) -> [(ext: String, success: Bool)]`
>   — for each extension, resolves UTI, calls
>   `LSSetDefaultRoleHandlerForContentType`. This is the ONLY place in the
>   codebase that calls LSSetDefaultRoleHandlerForContentType.
>
> Reference: DevFileTypes `set-handler.swift` `resolveUTType()` function
> for the UTI resolution pattern. Port it into a private helper here.
>
> **3. `Sources/CLIHandler.swift`**
>
> Parses `CommandLine.arguments` and dispatches subcommands.
> No external arg-parsing library.
>
> Subcommands (match docs/04-wireframes.md CLI section exactly):
>
> - `editor` — print current editor from ConfigStore
> - `editor <name>` — resolve via EditorShorthands, save to ConfigStore
> - `status` — call ExtensionRegistry.queryAllStatuses(), print formatted
>   table grouped by status (CLAIMED, OTHER, UNCLAIMED) with counts
> - `status --json` — same data as JSON array
> - `claim` — claim unclaimed extensions only
> - `claim --all` — claim unclaimed + contested
> - `install-cli` — create symlink
> - `uninstall` — remove symlink + clear UserDefaults
> - `--help` / `-h` — print usage (match docs/04-wireframes.md)
> - `--version` / `-v` — print "Trampoline 1.0"
>
> Exit codes: 0 = success, 1 = runtime error, 2 = usage error
>
> Wire into `TrampolineApp.swift`: in `applicationDidFinishLaunching`,
> replace the "CLI mode: not yet implemented" stub with a call to
> `CLIHandler.run()` which parses args and calls `exit()`.
>
> After creating the files, verify: `make clean && make all` compiles.

**Scope:**

- [ ] Delegate to `@code-writer` with the above prompt
- [ ] Verify: `make clean && make all` compiles
- [ ] Smoke test all CLI subcommands (see acceptance criteria)
- [ ] Delegate to `@code-review`: review all three files + the TrampolineApp.swift
      changes. Check: DRY adherence (no LS API calls outside ExtensionRegistry),
      exhaustive error handling, CLI output matches wireframes
- [ ] Fix any review findings
- [ ] Commit: `feat(cli): CLI handler with editor, status, and claim commands`
- [ ] Update this plan

**Acceptance criteria:**

- `trampoline editor` prints current editor (or "No editor configured")
- `trampoline editor zed` sets Zed and prints confirmation
- `trampoline status` prints extension table matching `docs/04-wireframes.md`
- `trampoline claim` claims unclaimed extensions, prints results
- `trampoline --help` prints usage matching wireframes
- `trampoline --version` prints "Trampoline 1.0"
- All LS API calls are in ExtensionRegistry (grep to verify: no other file
  imports CoreServices or calls LSCopy/LSSet)

**Status:**

| Step                             | Status | Notes                                         |
| -------------------------------- | ------ | --------------------------------------------- |
| Delegate to @code-writer         | done   |                                               |
| Build verification               | done   |                                               |
| CLI smoke tests                  | done   | all subcommands verified                      |
| DRY verification (grep LS calls) | done   | all 4 checks pass                             |
| Delegate to @code-review         | done   | 2 blockers, 4 issues, 5 nits                  |
| Fix review findings              | done   | symlink bug, DRY IDs, JSON, double query, etc |
| Commit                           | done   | 3bd87e2                                       |
| Plan updated                     | done   |                                               |

---

### TR-05: EditorDetector

**Estimated effort:** 0.5 session (30-60 min)
**Dependencies:** TR-04 (uses EditorShorthands)
**References:** `docs/01-architecture.md` (EditorDetector, open source references), `docs/05-data-model.md` (editor registry)

**Delegation prompt for `@code-writer`:**

> Create `Sources/EditorDetector.swift` for the Trampoline macOS app.
>
> This component scans the system for installed code editors.
> It consumes `EditorShorthands.all` (from `Sources/EditorShorthands.swift`)
> as the known editor list — do NOT duplicate the editor entries.
>
> ```swift
> struct EditorInfo: Identifiable {
>     let id: String          // bundleID
>     let bundleID: String
>     let displayName: String
>     let shorthand: String?  // nil for dynamically discovered
>     let appURL: URL
>     let icon: NSImage
> }
> ```
>
> Provide:
>
> - `static func detectInstalledEditors() -> [EditorInfo]`
>   - Iterate `EditorShorthands.all`
>   - For each, call `NSWorkspace.shared.urlForApplication(withBundleIdentifier:)`
>   - If found, load icon from the app bundle via `NSWorkspace.shared.icon(forFile:)`
>   - Filter out `com.maelos.trampoline` (Trampoline itself)
>   - Sort: alphabetical by displayName
>   - Return the list
>
> Reference pattern: DevFileTypes `set-default-editor.sh` uses
> `mdfind kMDItemCFBundleIdentifier` for discovery. Here we use the simpler
> NSWorkspace approach since we have a known list of bundle IDs.
>
> After creating the file, verify: `make clean && make all` compiles.

**Scope:**

- [ ] Delegate to `@code-writer` with the above prompt
- [ ] Verify: `make clean && make all` compiles
- [ ] Verify: detection finds Zed and any other installed editors
- [ ] Commit: `feat(core): EditorDetector for installed editor scanning`
- [ ] Update this plan

**Acceptance criteria:**

- Detects all installed known editors
- Returns app icon for each
- Returns empty array if no editors installed (no crash)
- Does not include Trampoline itself
- Consumes `EditorShorthands.all` (no duplicated editor list)

**Status:**

| Step                     | Status | Notes                           |
| ------------------------ | ------ | ------------------------------- |
| Delegate to @code-writer | done   |                                 |
| Build verification       | done   |                                 |
| Detection smoke test     | done   |                                 |
| Delegate to @code-review | done   | 0 blockers, 2 issues, 3 nits    |
| Fix review findings      | done   | dead code, .path deprecated, id |
| Commit                   | done   | 7fad488                         |
| Plan updated             | done   |                                 |

---

### TR-06: Settings Window — General Tab

**Estimated effort:** 1.5 sessions (2-3 hours)
**Dependencies:** TR-03 (ConfigStore), TR-05 (EditorDetector)
**References:** `docs/04-wireframes.md` (Screen 1, 1a, 1b)

**Delegation prompt for `@code-writer`:**

> Create the SwiftUI settings window for the Trampoline macOS app.
> Two files in `Sources/`.
>
> IMPORTANT: Before implementing, read the existing source files to
> understand the APIs available:
>
> - `Sources/ConfigStore.swift` — @Observable, singleton, properties
> - `Sources/EditorDetector.swift` — `detectInstalledEditors() -> [EditorInfo]`
> - `Sources/ExtensionRegistry.swift` — `queryAllStatuses()`
> - `Sources/FileForwarder.swift` — `pendingFiles`, `retryPending()`
>
> **1. `Sources/SettingsWindow.swift`**
>
> A SwiftUI window controller using `NSWindow` + `NSHostingController`.
> (We can't use SwiftUI `WindowGroup` because the app uses
> NSApplicationDelegate, not SwiftUI App protocol.)
>
> - Window title: "Trampoline"
> - Default size: 640x480, min: 540x400, max: 800x600
> - Tab bar with three tabs (toolbar style, like System Settings):
>   - General (SF Symbol: `gearshape`)
>   - Extensions (SF Symbol: `doc.plaintext`)
>   - About (SF Symbol: `info.circle`)
> - `static func show()` — create or bring to front
> - `static func showWithWarning(_ message: String)` — show with banner
>
> Wire into TrampolineApp.swift:
>
> - In `applicationDidFinishLaunching`: if not CLI mode and no file URLs,
>   call `SettingsWindow.show()`
> - In `applicationShouldHandleReopen`: call `SettingsWindow.show()`,
>   return true
> - In the `.noEditor`/`.editorNotFound` cases of file forwarding: call
>   `SettingsWindow.showWithWarning()`
>
> **2. `Sources/GeneralTab.swift`**
>
> SwiftUI view matching this wireframe:
>
> ```
> +------------------------------------------------------------+
> |                                                            |
> |  Default Editor                                            |
> |  [Picker: icon + name dropdown]                       [v]  |
> |                                                            |
> |  (i) When you open a developer file, Trampoline will      |
> |      forward it to {editor}.                              |
> |                                                            |
> |  [x] Show in menu bar          [Install CLI...]           |
> |                                                            |
> |  Extension Status                                          |
> |  84 managed | N claimed | N other | N unclaimed           |
> |  [Claim Unclaimed (N)]    [Claim All (N)]                  |
> |                                                            |
> +------------------------------------------------------------+
> ```
>
> - Editor picker: populated by `EditorDetector.detectInstalledEditors()`.
>   Show app icon (16x16) + display name. Include "Other..." option that
>   opens NSOpenPanel filtered to `.app`.
> - Info banner (contextual, using a `@ViewBuilder`):
>   - Normal: "When you open a developer file, Trampoline will forward it
>     to {editor}."
>   - First run (`!ConfigStore.shared.firstRunComplete`): welcome message
>   - Editor missing: warning style
>   - Pending files: "{N} file(s) waiting"
> - "Show in menu bar" checkbox bound to `ConfigStore.shared.showMenuBarIcon`
> - "Install CLI..." button calls `CLIHandler.installCLI()`
> - Extension status bar: counts from `ExtensionRegistry.queryAllStatuses()`
> - "Claim Unclaimed" and "Claim All" buttons call `ExtensionRegistry.claim()`
>
> When the editor picker selection changes:
>
> 1. Save to ConfigStore
> 2. If `FileForwarder.shared.pendingFiles` is not empty, call `retryPending()`
> 3. If `!firstRunComplete`, set `firstRunComplete = true`
>
> After creating the files, verify: `make clean && make all` compiles.

**Scope:**

- [ ] Delegate to `@code-writer` with the above prompt (include current
      source file contents for ConfigStore, EditorDetector, ExtensionRegistry,
      FileForwarder, and TrampolineApp as context)
- [ ] Verify: `make clean && make all` compiles
- [ ] LOOK: launch app manually, verify settings window appears
- [ ] LOOK: verify editor picker shows installed editors with icons
- [ ] LOOK: verify first-run banner shows on first launch
- [ ] Delegate to `@code-review`
- [ ] Fix findings
- [ ] Commit: `feat(gui): settings window with General tab`
- [ ] Update this plan

**Acceptance criteria:**

- Settings window opens on manual launch
- Editor picker shows installed editors with icons
- Selecting editor persists across app restart
- Info banner updates contextually
- Extension status counts match `trampoline status` CLI output
- "Claim Unclaimed" works
- Re-launching while running brings settings to front

**Status:**

| Step                     | Status  | Notes |
| ------------------------ | ------- | ----- |
| Delegate to @code-writer | pending |       |
| Build verification       | pending |       |
| LOOK: window opens       | pending |       |
| LOOK: picker + icons     | pending |       |
| LOOK: first-run banner   | pending |       |
| Delegate to @code-review | pending |       |
| Fix findings             | pending |       |
| Commit                   | pending | SHA:  |
| Plan updated             | pending |       |

---

### TR-07: Settings Window — Extensions Tab

**Estimated effort:** 1 session (1.5-2 hours)
**Dependencies:** TR-06, TR-04 (ExtensionRegistry)
**References:** `docs/04-wireframes.md` (Screen 2), `docs/03-flows.md` (F-04)

**Delegation prompt for `@code-writer`:**

> Create `Sources/ExtensionsTab.swift` for the Trampoline macOS app.
>
> IMPORTANT: Read `Sources/ExtensionRegistry.swift` first — all handler
> queries and claims MUST go through ExtensionRegistry. Do NOT call
> LaunchServices APIs directly from this file.
>
> SwiftUI view matching this wireframe:
>
> ```
> [Search field]                         [Claim All]
>
> | [] | Extension | Current Handler | Status    |
> |----|-----------|-----------------|-----------|
> | [] | .ts       | Trampoline      | Claimed   |
> | [] | .json     | Xcode           | Other     |
> | [] | .py       | (none)          | Unclaimed |
> | ...                                             |
>
> Selected: 0  |  [Claim Selected]  [Release Selected]
> ```
>
> Features:
>
> - Search field filters by extension name
> - Table with columns: checkbox (Toggle), Extension, Current Handler, Status
> - Status badges: Claimed (green), Other (orange), Unclaimed (gray)
>   Use SwiftUI `.badge()` or custom capsule with `.tint()`
> - Default sort: Status (Other first, Unclaimed, Claimed)
> - Column header click to sort
> - Multi-select checkboxes for batch operations
> - Footer shows selected count and action buttons
> - "Claim Selected" calls `ExtensionRegistry.claim(extensions:)`
> - "Claim All" claims all non-Claimed extensions
> - After claiming, refresh the status list
> - Show a ProgressView while querying handlers (84 queries)
>
> Data source: `ExtensionRegistry.queryAllStatuses()`
>
> Wire into `SettingsWindow.swift` as the second tab.

**Scope:**

- [ ] Delegate to `@code-writer` with the above prompt (include
      ExtensionRegistry.swift source as context)
- [ ] Verify: `make clean && make all` compiles
- [ ] LOOK: Extensions tab renders all 84 extensions
- [ ] LOOK: status badges show correct colors
- [ ] LOOK: search filters correctly
- [ ] LOOK: claiming updates status
- [ ] Delegate to `@code-review`
- [ ] Fix findings
- [ ] Commit: `feat(gui): Extensions tab with claim and release`
- [ ] Update this plan

**Acceptance criteria:**

- All 84 extensions appear in the table
- Status badges accurately reflect current handlers
- Claiming updates both LS database and table UI
- Search is responsive
- No LS API calls in this file (all via ExtensionRegistry)

**Status:**

| Step                     | Status  | Notes |
| ------------------------ | ------- | ----- |
| Delegate to @code-writer | pending |       |
| Build verification       | pending |       |
| LOOK: table renders      | pending |       |
| LOOK: badges correct     | pending |       |
| LOOK: search works       | pending |       |
| LOOK: claim works        | pending |       |
| Delegate to @code-review | pending |       |
| Fix findings             | pending |       |
| Commit                   | pending | SHA:  |
| Plan updated             | pending |       |

---

### TR-08: Menu Bar Item and About Tab

**Estimated effort:** 0.5 session (30-60 min)
**Dependencies:** TR-06
**References:** `docs/04-wireframes.md` (Menu Bar, Screen 3), `docs/01-architecture.md` (open source references: Ice, Hidden Bar)

**Delegation prompt for `@code-writer`:**

> Create two Swift source files for the Trampoline macOS app. `Sources/`.
>
> **1. `Sources/MenuBarManager.swift`**
>
> Manages an `NSStatusItem` in the macOS menu bar.
>
> - Icon: SF Symbol `arrow.up.right.square` (or similar; the icon should
>   suggest "forwarding/redirecting")
> - Menu items:
>   - "Editor: {name}" (disabled, updated reactively from ConfigStore)
>   - "{N} extensions managed" (disabled)
>   - NSMenuItem.separator()
>   - "Settings..." (action: `SettingsWindow.show()`)
>   - NSMenuItem.separator()
>   - "Quit Trampoline" (action: `NSApplication.shared.terminate(nil)`)
> - Visibility: observe `ConfigStore.shared.showMenuBarIcon`. Show/hide
>   the status item when the setting changes.
> - Singleton: `static let shared = MenuBarManager()`
> - `func setup()` — create the status item if `showMenuBarIcon` is true
> - `func teardown()` — remove the status item
>
> Wire into TrampolineApp.swift: call `MenuBarManager.shared.setup()` in
> `applicationDidFinishLaunching` (when not in CLI mode).
>
> Reference: Ice (github.com/jordanbaird/Ice) for NSStatusItem patterns.
>
> **2. `Sources/AboutTab.swift`**
>
> SwiftUI view:
>
> - App icon (from bundle, centered, 64x64)
> - "Trampoline" (title, `.title` font)
> - "Version {CFBundleShortVersionString}" (secondary text)
> - Description: "Trampoline registers itself as the default handler for
>   developer file extensions, then silently forwards files to your
>   preferred code editor."
> - Two link buttons: "GitHub Repository", "Report an Issue"
>   (placeholder URLs for now)
> - "License: MIT" (footer text)
>
> Wire into `SettingsWindow.swift` as the third tab.

**Scope:**

- [ ] Delegate to `@code-writer` with the above prompt (include
      ConfigStore.swift and SettingsWindow.swift source as context)
- [ ] Verify: `make clean && make all` compiles
- [ ] Verify: menu bar icon appears when enabled
- [ ] Verify: menu bar "Settings..." opens settings window
- [ ] Verify: "Quit Trampoline" terminates the app
- [ ] Verify: About tab displays correctly
- [ ] Commit: `feat(gui): menu bar item and About tab`
- [ ] Update this plan

**Acceptance criteria:**

- Menu bar icon appears when `showMenuBarIcon` is true
- Menu bar icon disappears when setting is toggled off
- "Settings..." opens the settings window
- "Quit" terminates the app
- About tab shows correct version from bundle

**Status:**

| Step                     | Status  | Notes |
| ------------------------ | ------- | ----- |
| Delegate to @code-writer | pending |       |
| Build verification       | pending |       |
| Menu bar verification    | pending |       |
| About tab verification   | pending |       |
| Commit                   | pending | SHA:  |
| Plan updated             | pending |       |

---

### TR-09: First-Run and Error Recovery Flows

**Estimated effort:** 1 session (1-2 hours)
**Dependencies:** TR-06, TR-07
**References:** `docs/03-flows.md` (F-01, F-08, F-09), `docs/02-use-cases.md` (UC-1, UC-9, UC-10)

**Delegation prompt for `@code-writer`:**

> Update the Trampoline macOS app to implement three recovery flows.
> Read all existing source files first to understand the current
> architecture.
>
> **Flow 1: First-run (docs/03-flows.md F-01)**
>
> In `GeneralTab.swift`:
>
> - When `ConfigStore.shared.firstRunComplete == false`:
>   - Show welcome banner: "Welcome to Trampoline — Trampoline makes
>     developer files open in your preferred code editor. Choose your
>     editor below to get started."
>   - Hide the extension status bar and claim buttons until an editor
>     is selected
> - When the user selects an editor:
>   - Show extension status and claim buttons
>   - Auto-count unclaimed extensions and show "Claim Unclaimed (N)"
> - After claiming (or if user skips): set `firstRunComplete = true`
>
> **Flow 2: No-editor recovery (docs/03-flows.md F-08)**
>
> In `TrampolineApp.swift` (the AppDelegate):
>
> - When `FileForwarder.forward()` returns `.noEditor`:
>   - Call `SettingsWindow.showWithWarning("Choose an editor to open
your files")` (or similar)
> - In `GeneralTab.swift`:
>   - When `FileForwarder.shared.pendingFiles.count > 0`:
>     - Show banner: "{N} file(s) waiting. Choose an editor to open them."
>   - When editor is selected and pendingFiles exist: call `retryPending()`
>
> **Flow 3: Editor-not-found recovery (docs/03-flows.md F-09)**
>
> In `TrampolineApp.swift`:
>
> - When `FileForwarder.forward()` returns `.editorNotFound`:
>   - Call `SettingsWindow.showWithWarning("{editorName} is no longer
installed. Choose a different editor.")`
> - In `GeneralTab.swift`:
>   - The existing warning banner logic should handle this (the
>     editor picker shows the missing editor with a warning icon)
>
> After changes, verify: `make clean && make all` compiles.

**Scope:**

- [ ] Delegate to `@code-writer` with the above prompt (include ALL current
      source files as context since this touches multiple files)
- [ ] Verify: `make clean && make all` compiles
- [ ] Test: delete UserDefaults, launch app -> welcome banner appears
- [ ] Test: set no editor, double-click file -> settings opens with pending
      files banner
- [ ] Test: set editor to nonexistent bundle ID, double-click file ->
      settings opens with "not installed" warning
- [ ] Delegate to `@code-review`
- [ ] Fix findings
- [ ] Commit: `feat(core): first-run and error recovery flows`
- [ ] Update this plan

**Acceptance criteria:**

- First launch with no config -> welcome banner, guided setup
- File opened with no editor -> settings + pending files banner -> selection
  forwards the pending files
- File opened with uninstalled editor -> settings + warning -> new selection
  forwards the pending files
- Pending files cleared after successful forwarding (no duplicates)

**Status:**

| Step                     | Status  | Notes |
| ------------------------ | ------- | ----- |
| Delegate to @code-writer | pending |       |
| Build verification       | pending |       |
| First-run flow test      | pending |       |
| No-editor recovery test  | pending |       |
| Editor-not-found test    | pending |       |
| Delegate to @code-review | pending |       |
| Fix findings             | pending |       |
| Commit                   | pending | SHA:  |
| Plan updated             | pending |       |

---

### TR-10: Install Targets and Homebrew Preparation

**Estimated effort:** 0.5 session (30-60 min)
**Dependencies:** TR-04
**References:** `docs/01-architecture.md` (bundle structure)

**Delegation prompt for `@code-writer`:**

> Update the Makefile for the Trampoline macOS app and create a Homebrew
> cask formula draft.
>
> **1. Update `Makefile` `install` target:**
>
> ```makefile
> install: all
> 	@echo "Installing Trampoline.app..."
> 	cp -R Trampoline.app /Applications/
> 	$(LSREGISTER) -f /Applications/Trampoline.app
> 	@echo "Creating CLI symlink..."
> 	ln -sf /Applications/Trampoline.app/Contents/MacOS/Trampoline \
> 		/usr/local/bin/trampoline
> 	@echo "Done. Run 'trampoline --help' to get started."
> ```
>
> **2. Update `Makefile` `uninstall` target:**
>
> ```makefile
> uninstall:
> 	@echo "Removing Trampoline..."
> 	rm -f /usr/local/bin/trampoline
> 	rm -rf /Applications/Trampoline.app
> 	@echo "Clearing preferences..."
> 	defaults delete com.maelos.trampoline 2>/dev/null || true
> 	@echo "Done."
> ```
>
> **3. Create `trampoline.rb`** — Homebrew cask formula draft:
>
> ```ruby
> cask "trampoline" do
>   version "1.0"
>   sha256 "PLACEHOLDER"
>   url "https://github.com/maelos/trampoline/releases/download/v#{version}/Trampoline-#{version}.zip"
>   name "Trampoline"
>   desc "Developer file handler trampoline for macOS"
>   homepage "https://github.com/maelos/trampoline"
>   app "Trampoline.app"
>   binary "#{appdir}/Trampoline.app/Contents/MacOS/Trampoline", target: "trampoline"
>   postflight do
>     system_command "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
>       args: ["-f", "#{appdir}/Trampoline.app"]
>   end
>   zap trash: [
>     "~/Library/Preferences/com.maelos.trampoline.plist",
>   ]
> end
> ```

**Scope:**

- [ ] Delegate to `@code-writer` with the above prompt
- [ ] Verify: `make install` places app and creates symlink
- [ ] Verify: `trampoline --help` works after install
- [ ] Verify: `make uninstall` cleanly removes both
- [ ] Commit: `chore(build): install and uninstall targets, Homebrew formula`
- [ ] Update this plan

**Acceptance criteria:**

- `make install` places app and creates working CLI symlink
- `make uninstall` cleanly removes both
- Homebrew formula is syntactically valid Ruby

**Status:**

| Step                     | Status  | Notes |
| ------------------------ | ------- | ----- |
| Delegate to @code-writer | pending |       |
| Install cycle test       | pending |       |
| Uninstall cycle test     | pending |       |
| Commit                   | pending | SHA:  |
| Plan updated             | pending |       |

---

### TR-11: README and Final Review

**Estimated effort:** 1 session (1-2 hours)
**Dependencies:** All previous tasks
**References:** All design docs

**Scope:**

- [ ] Delegate to `@docs-writer`: "Write README.md for the Trampoline macOS
      app. Reference docs/00-overview.md for the problem statement and
      docs/04-wireframes.md for CLI examples. Include: what it does,
      how it works (the trampoline pattern), installation (Homebrew, manual),
      usage (GUI + CLI), managed extensions table, building from source,
      comparison with duti/OpenIn/Finicky, license (MIT)."
- [ ] Delegate to `@code-review`: "Full review of ALL Swift source files in
      Sources/, the Info.plist, and Makefile. Check: correctness, error handling,
      macOS API usage, DRY adherence (all LS calls in ExtensionRegistry, all
      editor data in EditorShorthands), no force-unwraps, no TODO/FIXME
      comments, code clarity."
- [ ] Fix all review findings (delegate to `@code-writer` if needed)
- [ ] Re-review if fixes were substantial
- [ ] Final smoke test: `make clean && make all && make install`
- [ ] Commit: `docs: README and final cleanup`
- [ ] Update this plan: mark all steps done

**Acceptance criteria:**

- README is comprehensive and accurate
- `@code-review` returns zero blockers on the full codebase
- `make clean && make all` builds cleanly
- `make install` -> full end-to-end test passes
- No TODO/FIXME comments in source
- All LS API calls are in ExtensionRegistry.swift (grep to verify)
- All editor data is in EditorShorthands.swift (grep to verify)

**Status:**

| Step                     | Status  | Notes |
| ------------------------ | ------- | ----- |
| Delegate to @docs-writer | pending |       |
| Delegate to @code-review | pending |       |
| Fix review findings      | pending |       |
| Re-review (if needed)    | pending |       |
| Final smoke test         | pending |       |
| Commit                   | pending | SHA:  |
| Plan updated             | pending |       |

---

## Validation Protocol

**Standard validation sequence (per task):**

1. **Build** — `make clean && make all` (must compile with zero warnings)
2. **Lint** — `swiftc` with `-warnings-as-errors` flag in Makefile
3. **Smoke test** — run the binary in the relevant mode (CLI, file forward, GUI)
4. **LOOK checkpoint** (if UI changed) — visual verification
5. **Code review** — `@code-review` delegation, fix-review loop until zero issues
6. **Commit** — only after steps 1-5 pass
7. **Plan update** — update status tables immediately after commit

---

## Commit Protocol

**Format:** Conventional Commits

```
<type>(scope): <summary>

<body>
```

- **type**: `feat`, `fix`, `refactor`, `docs`, `chore`, `build`
- **scope**: component name (`core`, `cli`, `gui`, `plist`, `build`)
- **summary**: imperative, specific, no trailing period
- **body**: bullet points of what changed, wrapped at 72 chars

**Commit timing:**

- Commit at the end of every completed task (after validation passes)
- Commit at natural sub-task checkpoints within larger tasks (TR-03, TR-06)
  to avoid losing work
- Never commit code that doesn't build
- Never commit before code review passes (for tasks with review steps)

**Commit-per-task mapping:**

| Task  | Commit Message                                                   |
| ----- | ---------------------------------------------------------------- |
| TR-01 | `chore(build): project skeleton and build system`                |
| TR-02 | `feat(plist): UTI declarations and CFBundleDocumentTypes`        |
| TR-03 | `feat(core): ConfigStore, FileForwarder, and AppDelegate`        |
| TR-04 | `feat(cli): CLI handler with editor, status, and claim commands` |
| TR-05 | `feat(core): EditorDetector for installed editor scanning`       |
| TR-06 | `feat(gui): settings window with General tab`                    |
| TR-07 | `feat(gui): Extensions tab with claim and release`               |
| TR-08 | `feat(gui): menu bar item and About tab`                         |
| TR-09 | `feat(core): first-run and error recovery flows`                 |
| TR-10 | `chore(build): install and uninstall targets, Homebrew formula`  |
| TR-11 | `docs: README and final cleanup`                                 |

**After committing:** update the task's status table Notes column with the
short SHA.

---

## DRY Verification Checklist

Run these checks after TR-04 and before the final commit (TR-11):

```bash
# Verify: only ExtensionRegistry.swift calls LaunchServices APIs
grep -rn "LSCopyDefault\|LSSetDefault\|LSCopyAll" Sources/ | grep -v ExtensionRegistry

# Verify: only EditorShorthands.swift defines editor bundle IDs
grep -rn "com\.microsoft\.VSCode\|dev\.zed\.Zed\|com\.sublimetext" Sources/ | grep -v EditorShorthands

# Verify: no force-unwrapping
grep -rn '![^=]' Sources/*.swift | grep -v '!=' | grep -v '!//' | grep -v 'import'

# Verify: no TODO/FIXME
grep -rn 'TODO\|FIXME\|HACK\|XXX' Sources/
```

---

## File Impact Summary

### Files Created

| File                                 | Task         | Purpose                                         |
| ------------------------------------ | ------------ | ----------------------------------------------- |
| `Sources/TrampolineApp.swift`        | TR-01, TR-03 | App entry point and delegate                    |
| `Sources/ConfigStore.swift`          | TR-03        | UserDefaults wrapper (single config source)     |
| `Sources/FileForwarder.swift`        | TR-03        | File open event handler                         |
| `Sources/CLIHandler.swift`           | TR-04        | CLI argument parser and dispatcher              |
| `Sources/EditorShorthands.swift`     | TR-04        | Known editor registry (single editor source)    |
| `Sources/ExtensionRegistry.swift`    | TR-04        | Extension + LS API registry (single ext source) |
| `Sources/EditorDetector.swift`       | TR-05        | Installed editor scanner                        |
| `Sources/SettingsWindow.swift`       | TR-06        | SwiftUI window container                        |
| `Sources/GeneralTab.swift`           | TR-06        | General settings tab                            |
| `Sources/ExtensionsTab.swift`        | TR-07        | Extensions management tab                       |
| `Sources/AboutTab.swift`             | TR-08        | About tab                                       |
| `Sources/MenuBarManager.swift`       | TR-08        | NSStatusItem management                         |
| `Trampoline.app/Contents/Info.plist` | TR-02        | UTIs + CFBundleDocumentTypes                    |
| `Makefile`                           | TR-01, TR-10 | Build system                                    |
| `.gitignore`                         | TR-01        | Ignore patterns                                 |
| `README.md`                          | TR-11        | Project documentation                           |
| `trampoline.rb`                      | TR-10        | Homebrew cask formula (draft)                   |

### Files from Design Phase (Pre-existing)

| File                      | Purpose                                                             |
| ------------------------- | ------------------------------------------------------------------- |
| `docs/00-overview.md`     | Design spec: overview                                               |
| `docs/01-architecture.md` | Design spec: architecture + DRY principles + open source references |
| `docs/02-use-cases.md`    | Design spec: use cases                                              |
| `docs/03-flows.md`        | Design spec: flow diagrams                                          |
| `docs/04-wireframes.md`   | Design spec: wireframes                                             |
| `docs/05-data-model.md`   | Design spec: data model                                             |
| `docs/06-phases.md`       | Design spec: phases                                                 |
| `docs/PLAN.md`            | This implementation plan                                            |

---

## Risk Register

| Risk                                                    | Likelihood | Impact | Mitigation                                                                    |
| ------------------------------------------------------- | ---------- | ------ | ----------------------------------------------------------------------------- |
| macOS dialog on `LSHandlerRank=Default` for custom UTIs | Low        | High   | Test on clean user account; if dialogs appear, fall back to Alternate rank    |
| `application(_:open:)` not called for unclaimed types   | Medium     | High   | Verify CFBundleDocumentTypes wiring; may need CFBundleTypeExtensions fallback |
| SwiftUI settings window blocks file forwarding          | Low        | Medium | Use separate NSWindow, ensure event loop isn't blocked                        |
| `lsregister -f` no longer works on modern macOS         | Low        | Medium | Test on macOS 14+; may need alternative registration                          |
| CLI symlink requires sudo                               | Medium     | Low    | Document in README; offer `~/bin` alternative                                 |
| Editor detection misses JetBrains Toolbox installs      | Medium     | Low    | Handle in EditorDetector with broader search                                  |

---

## Rollback Plan

Each task commits independently. To roll back:

| Task     | Rollback                                          |
| -------- | ------------------------------------------------- |
| TR-01    | Delete the repo                                   |
| TR-02    | `git revert` — Info.plist is self-contained       |
| TR-03    | `git revert` — reverts to stub entry point        |
| TR-04    | `git revert` — CLI is additive                    |
| TR-05    | `git revert` — EditorDetector is additive         |
| TR-06-08 | `git revert` — GUI is additive; app works via CLI |
| TR-09    | `git revert` — recovery flows are additive        |
| TR-10    | `git revert` — Makefile targets are additive      |
| TR-11    | `git revert` — README is additive                 |

---

## Out of Scope

| Item                         | Rationale                                           |
| ---------------------------- | --------------------------------------------------- |
| Per-extension editor routing | Adds complexity; v1 routes everything to one editor |
| URL scheme handling          | Finicky handles this; different domain              |
| Quick Look integration       | Orthogonal; stays in DevFileTypes                   |
| File type icon customization | Nice-to-have; not core value                        |
| Mac App Store distribution   | Requires sandbox; limits handler registration       |
| Auto-update mechanism        | Homebrew handles updates; Sparkle adds dependency   |
| Code signing + notarization  | Handle at release time, not development             |
| Windows/Linux support        | macOS-only APIs throughout                          |

---

## Post-Completion Checklist

- [ ] `make clean && make all` builds cleanly on a fresh checkout
- [ ] `make install` places app and creates CLI symlink
- [ ] First-run flow works (no config -> welcome -> editor selection -> claiming)
- [ ] File forwarding works for custom UTI, system UTI, and dynamic UTI extensions
- [ ] CLI `editor`, `status`, `claim`, `install-cli` produce correct output
- [ ] Menu bar icon appears/disappears based on setting
- [ ] Settings window opens from menu bar, re-launch, and missing-editor scenarios
- [ ] Extensions tab shows accurate handler status for all 84 extensions
- [ ] `make uninstall` cleanly removes app and symlink
- [ ] DRY verification checklist passes (all LS calls in ExtensionRegistry, etc.)
- [ ] No TODO/FIXME comments in source
- [ ] README covers installation, usage, building, and comparison
- [ ] `@code-review` returns zero blockers on final codebase
- [ ] All status tables in this plan are marked done with commit SHAs
