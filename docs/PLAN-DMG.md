# DMG Packaging & Self-Registration Plan

**Version:** 2.0
**Date:** 2026-03-30
**Status:** Ready for execution (post-review revision)
**Branch:** `main`
**Source:** User request (2026-03-30 session)
**Estimated total effort:** 2-3 hours (1 session)
**Dependencies:** swiftc, AppKit, hdiutil, create-dmg (`brew install create-dmg`)

---

## How to Use This Document

This plan is designed for execution by an **orchestrator agent** that
delegates implementation to specialized agents (`@code-writer`,
`@code-review-opus`, `@code-review-gpt5`, `@docs-writer`) while
maintaining full project context.

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

### Context Window Strategy

- **Do NOT compact mid-project** — retain full context across all tasks.
- **Include all necessary context in delegation prompts** — delegated
  agents have no prior context.

### Resuming Mid-Plan

1. Read this entire document
2. Run `git log --oneline -20` and `git status` to orient
3. Check per-task status tables for the first incomplete step
4. Read source files created by completed tasks to rebuild context
5. Resume from the first incomplete step

### Authoritative References

| Document                             | Purpose                                 |
| ------------------------------------ | --------------------------------------- |
| `docs/PLAN.md`                       | Main implementation plan (Phases 1-5)   |
| `Sources/TrampolineApp.swift`        | App entry point, AppDelegate, first-run |
| `Sources/CLIHandler.swift`           | CLI commands including `installCLI()`   |
| `Makefile`                           | Build, install, uninstall targets       |
| `Trampoline.app/Contents/Info.plist` | App bundle metadata                     |

### Validation Commands

```bash
# Build (must pass before every commit)
make clean && make all

# DMG creation
make dmg

# Smoke test: mount DMG, drag to /Applications, launch, verify first-run
open Trampoline.dmg
# Then drag Trampoline.app to Applications alias
# Launch from /Applications/Trampoline.app
# Verify: lsregister runs, menu bar icon appears, settings opens on first run
```

---

## Decision Log

| #   | Topic                            | Decision                                                                                                                               | Rationale                                                                                                                                                                  |
| --- | -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | DMG tool                         | Use `create-dmg` (shell script, Homebrew installable, no runtime deps)                                                                 | Pure shell, widely adopted (2.5k stars), no Node/Python dependency. Falls back to hdiutil natively.                                                                        |
| 2   | Codesigning timing               | Ad-hoc codesign the `.app` BEFORE packaging into DMG, not at install time                                                              | The DMG contents are read-only once mounted. The user drags a pre-signed app. `make install` codesign stays as a developer convenience.                                    |
| 3   | Self-registration                | On first launch from `/Applications`, run `lsregister -f` on self. On every launch, check and offer to move if not in `/Applications`. | Standard macOS pattern. lsregister is idempotent. The "move to Applications" prompt prevents running from the DMG mount point (read-only, will break).                     |
| 4   | CLI symlink                      | Offer to install CLI symlink during first-run flow (GUI button already exists). Don't auto-install — requires admin privileges.        | Consistent with existing behavior. The GUI "Install CLI..." button with AppleScript privilege escalation already works.                                                    |
| 5   | Move-to-Applications             | Show an alert on launch if `Bundle.main.bundlePath` does NOT start with `/Applications/`. Offer to move automatically.                 | Prevents running from DMG (read-only volume), Downloads, Desktop, etc. Many macOS apps do this (Sublime Text, VS Code, etc.).                                              |
| 6   | Background image                 | Skip for v1. Use `create-dmg` defaults (clean white, app icon + Applications alias with arrow).                                        | A custom background image adds visual polish but isn't necessary for functionality. Can be added later.                                                                    |
| 7   | `make dmg` target                | New Makefile target that depends on `all`, codesigns, then runs `create-dmg`.                                                          | Keeps the build pipeline simple: `make all` builds, `make dmg` packages.                                                                                                   |
| 8   | DMG filename                     | `Trampoline-<version>.dmg` where version comes from `ExtensionRegistry.version`                                                        | Standard convention. Version in filename helps distinguish releases.                                                                                                       |
| 9   | Move semantics                   | Try `moveItem` first (atomic on same volume), fall back to `copyItem` + delete source on cross-volume.                                 | Avoids leaving a duplicate in Downloads. `moveItem` fails across volumes; `copyItem` + `try? removeItem` handles DMG (read-only source, delete fails silently). Review B1. |
| 10  | Atomic replace                   | Copy to temp path `/Applications/.Trampoline.app.new`, then `replaceItemAt` or remove-old + rename-new.                                | Never delete the working install before the new copy succeeds. Review B2.                                                                                                  |
| 11  | Relaunch flag                    | Use `open` without `-n`. Add `task.waitUntilExit()` before `NSApp.terminate(nil)`.                                                     | `-n` forces a new instance causing races. `waitUntilExit` ensures Launch Services has received the request. Review B2/I6.                                                  |
| 12  | `~/Applications` valid           | Check both `/Applications/` and `~/Applications/` as valid install locations.                                                          | macOS supports per-user Applications folder. Some users prefer it. Review I1.                                                                                              |
| 13  | lsRegistered version key         | Store `lsRegisteredVersion` (String) instead of `lsRegistered` (Bool). Re-register when version changes.                               | Ensures UTI declarations are re-registered after upgrades. Review I2.                                                                                                      |
| 14  | lsRegister only from install dir | Only run lsregister if the app is in `/Applications/` or `~/Applications/`. Skip otherwise.                                            | Prevents registering a transient path (DMG, Downloads). Review B-GPT5-1.                                                                                                   |
| 15  | Forced move failure path         | If copy-to-Applications fails from DMG, show alert with manual instructions ("Drag from Finder") + Quit.                               | User is stuck on a read-only volume; must have a clear escape. Review B-GPT5-3.                                                                                            |
| 16  | File-open on relaunch            | Not preserved. First launch after move won't have pending files — user double-clicked the app, not a file.                             | The move prompt only appears on first launch when no files are open. Subsequent file-open events go to the already-running installed copy. Review B-GPT5-4.                |
| 17  | `--volicon` safety               | Verify `AppIcon.icns` exists at build time. If absent, omit `--volicon` flag.                                                          | The icns is in the pre-built bundle skeleton but not generated by `make all`. Review B3.                                                                                   |
| 18  | Staging dir uses `ditto`         | Use `ditto` instead of `cp -R` for staging to preserve codesigning metadata.                                                           | `ditto` handles macOS extended attributes and resource forks correctly. Review S4.                                                                                         |
| 19  | `create-dmg` exit code 2         | Treat exit code 2 (Finder cosmetics failed) as success: `create-dmg ... \|\| test $$? -eq 2`.                                          | Common in headless/CI environments. DMG is still valid. Review I3.                                                                                                         |
| 20  | Preflight `create-dmg`           | Check `command -v create-dmg` before running. Print install instructions if missing.                                                   | Fail early with clear message. Review S5.                                                                                                                                  |
| 21  | Dev suppress prompt              | For non-`/Volumes/` paths, add a "Don't ask again" option that sets a UserDefaults flag.                                               | Developers running from build directory shouldn't be nagged on every launch. Review S2.                                                                                    |
| 22  | Gatekeeper/quarantine            | Document as limitation. Ad-hoc signing doesn't pass Gatekeeper. Users may need to right-click → Open first.                            | Notarization requires Apple Developer account. Out of scope for v1. Review GPT5-I6.                                                                                        |

---

## DRY Invariants

Existing invariants from the main plan still apply. No new invariants
introduced by this work.

| #   | Invariant                       | Canonical location        | Grep check                                                                                                             |
| --- | ------------------------------- | ------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| 1   | All LaunchServices API calls    | `ExtensionRegistry.swift` | `grep -rn 'LSSetDefaultRoleHandler\|LSCopyDefaultRoleHandler\|lsregister' Sources/ \| grep -v ExtensionRegistry.swift` |
| 2   | No force-unwrapping             | Everywhere                | `grep -rn '!' Sources/ \| grep -v '//' \| grep -v 'import' \| grep -v 'isEmpty'`                                       |
| 3   | No TODO/FIXME in committed code | Everywhere                | `grep -rn 'TODO\|FIXME\|HACK\|XXX' Sources/`                                                                           |

**Note on invariant 1:** The `lsregister` call for self-registration
will live in `TrampolineApp.swift` (the AppDelegate), NOT in
ExtensionRegistry. This is intentional — it's a one-time app lifecycle
action (registering the bundle with LaunchServices), not an extension
management API. The `lsregister` binary path constant can be shared or
duplicated since it's a system path, not business logic. Update the grep
to exclude `TrampolineApp.swift` as well.

---

## Execution Sequence

```
Phase 1: Self-Registration on First Launch
  DMG-01 (move-to-Applications check) -> build -> LOOK -> review -> commit
  DMG-02 (self-register with lsregister) -> build -> review -> commit

Phase 2: DMG Packaging
  DMG-03 (Makefile dmg target) -> build -> test -> review -> commit
```

---

## Phases

### Phase 1: Self-Registration on First Launch

**Goal:** When the user launches Trampoline.app for the first time after
dragging it to /Applications, the app:

1. Checks if it's running from /Applications — if not, offers to move
2. Runs `lsregister -f` on itself to register UTI declarations
3. Proceeds with the existing first-run flow (show settings, pick editor)

This replaces the `make install` steps for end users while keeping
`make install` as a developer convenience.

---

### DMG-01: Move-to-Applications Check

**Estimated effort:** 30 minutes
**Dependencies:** None
**Files:** `Sources/TrampolineApp.swift`

**Delegation prompt for `@code-writer`:**

> Add a "move to Applications" check to Trampoline's app launch.
>
> File: `/Users/rmk/projects/tools/trampoline/Sources/TrampolineApp.swift`
>
> **Current behavior:** The `applicationDidFinishLaunching` method in
> `AppDelegate` checks for CLI mode, sets up the menu bar, and shows
> settings on first run.
>
> **New behavior:** Before the menu bar setup (but after the CLI mode
> check), add a check:
>
> ```swift
> // Check if the app is running from a valid install location.
> let bundlePath = Bundle.main.bundlePath
> let validPrefixes = ["/Applications/",
>                      NSHomeDirectory() + "/Applications/"]
> let isInstalled = validPrefixes.contains { bundlePath.hasPrefix($0) }
>
> if !isInstalled {
>     // Check if user previously chose "Don't ask again"
>     if !ConfigStore.shared.suppressMovePrompt {
>         let onDMG = bundlePath.hasPrefix("/Volumes/")
>         let action = showMoveToApplicationsAlert(forcedMove: onDMG)
>         switch action {
>         case .move:
>             if moveToApplications() { return }
>             // moveToApplications shows its own error; continue running
>         case .quit:
>             NSApp.terminate(nil)
>             return
>         case .notNow:
>             break  // continue running from current location
>         case .dontAskAgain:
>             ConfigStore.shared.suppressMovePrompt = true
>         }
>     }
> }
> ```
>
> **ConfigStore addition** (in ConfigStore.swift):
>
> ```swift
> var suppressMovePrompt: Bool = false {
>     didSet { defaults.set(suppressMovePrompt, forKey: "suppressMovePrompt") }
> }
> // Initialize in init():
> self.suppressMovePrompt = defaults.bool(forKey: "suppressMovePrompt")
> ```
>
> **`MoveAction` enum:**
>
> ```swift
> private enum MoveAction {
>     case move, quit, notNow, dontAskAgain
> }
> ```
>
> **`showMoveToApplicationsAlert(forcedMove:)`** — Show an `NSAlert`:
>
> - `NSApp.activate(ignoringOtherApps: true)` before showing (so the
>   alert is frontmost — app is an LSUIElement agent)
> - Style: `.informational`
> - If `forcedMove` (DMG):
>   - Message: "Move to Applications"
>   - Informative: "Trampoline is running from a disk image. It
>     must be installed in Applications to work properly."
>   - Buttons: "Move to Applications" (default), "Quit"
>   - Returns `.move` or `.quit`
> - If NOT `forcedMove`:
>   - Message: "Move to Applications?"
>   - Informative: "Trampoline works best when installed in your
>     Applications folder. Would you like to move it there now?"
>   - Buttons: "Move to Applications" (default), "Not Now",
>     "Don't Ask Again"
>   - Returns `.move`, `.notNow`, or `.dontAskAgain`
>
> **`moveToApplications()`** — Returns `true` if relaunch was initiated:
>
> 1. `let source = Bundle.main.bundleURL`
> 2. `let dest = URL(fileURLWithPath: "/Applications/Trampoline.app")`
> 3. `let fm = FileManager.default`
> 4. **Atomic replace strategy:**
>    - `let tempDest = dest.appendingPathExtension("new")` (i.e.
>      `/Applications/Trampoline.app.new`)
>    - Remove any stale temp: `try? fm.removeItem(at: tempDest)`
>    - Try `fm.moveItem(at: source, to: tempDest)` first (atomic on
>      same volume, e.g. if user has it on Desktop)
>    - If moveItem fails (cross-volume — e.g. DMG), fall back to
>      `fm.copyItem(at: source, to: tempDest)` and then
>      `try? fm.removeItem(at: source)` (fails silently on read-only)
>    - If both fail, show an error alert:
>      "Could not install Trampoline. Drag Trampoline.app from
>      Finder into your Applications folder, then relaunch."
>      Return `false`.
>    - If the existing dest exists, remove it:
>      `try? fm.removeItem(at: dest)` (old install)
>    - Rename temp to final: `try fm.moveItem(at: tempDest, to: dest)`
>    - If rename fails, show error alert, return `false`.
> 5. **Relaunch from installed location:**
>    ```swift
>    let task = Process()
>    task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
>    task.arguments = [dest.path]
>    try task.run()
>    task.waitUntilExit()
>    NSApp.terminate(nil)
>    ```
>    Return `true`.
>
> **Error alert helper:**
>
> ```swift
> private func showMoveErrorAlert(_ message: String) {
>     let alert = NSAlert()
>     alert.messageText = "Installation Failed"
>     alert.informativeText = message
>     alert.alertStyle = .warning
>     alert.addButton(withTitle: "OK")
>     alert.runModal()
> }
> ```
>
> Add all methods as `private` methods on `AppDelegate`.
>
> **Constraints:** Compiles with `swiftc -O -warnings-as-errors`. No
> force-unwrapping. No TODO/FIXME.

**Review criteria for `@code-review-opus` / `@code-review-gpt5`:**

> - Alert is shown before menu bar setup
> - DMG detection (`/Volumes/`) forces move (no "Not Now")
> - Both `/Applications/` and `~/Applications/` are valid
> - Atomic replace: temp copy, then swap — never delete install first
> - `moveItem` tried first, `copyItem` fallback for cross-volume
> - Source cleanup: `try? removeItem` on source (silent fail on DMG)
> - Relaunch uses `Process("/usr/bin/open")` WITHOUT `-n`
> - `waitUntilExit()` before `NSApp.terminate`
> - Error path: if copy fails, shows actionable message, returns false
> - "Don't Ask Again" persisted in ConfigStore
> - `NSApp.activate(ignoringOtherApps:)` before showing alert
> - No force-unwrapping
> - CLI mode is unaffected (check is after CLI dispatch)

**Acceptance criteria:**

- Build compiles with zero warnings
- Launching from `/tmp/` shows the move alert with 3 options
- Launching from a DMG mount shows forced move (no "Not Now")
- Clicking "Move to Applications" moves the app and relaunches
- "Don't Ask Again" suppresses future prompts
- Launching from `/Applications/` shows no alert
- Launching from `~/Applications/` shows no alert
- CLI mode (`trampoline status`) is unaffected
- If copy fails, error alert shows manual install instructions

**Status:**

| Step                        | Status  | Notes |
| --------------------------- | ------- | ----- |
| Delegate to @code-writer    | pending |       |
| Build verification          | pending |       |
| Smoke test                  | pending |       |
| Visual verification (if UI) | pending |       |
| @code-review-opus           | pending |       |
| @code-review-gpt5           | pending |       |
| Fix review findings         | pending |       |
| Commit                      | pending | SHA:  |
| Plan updated                | pending |       |

---

### DMG-02: Self-Register with lsregister on Launch

**Estimated effort:** 20 minutes
**Dependencies:** DMG-01 (location check should run first)
**Files:** `Sources/TrampolineApp.swift`

**Delegation prompt for `@code-writer`:**

> Add automatic lsregister self-registration to Trampoline's launch.
>
> File: `/Users/rmk/projects/tools/trampoline/Sources/TrampolineApp.swift`
>
> **Context:** When users install via `make install`, the Makefile runs
> `lsregister -f /Applications/Trampoline.app` to register the app's
> UTI declarations with LaunchServices. When users install via DMG
> (drag to /Applications), this step is skipped. The app needs to
> register itself on first launch.
>
> **Change:** After the move-to-Applications check (added in DMG-01)
> and before the menu bar setup, add:
>
> ```swift
> // Self-register with LaunchServices on first launch or after upgrade.
> // Only register from an installed location (/Applications/ or ~/Applications/).
> // Use a version-keyed flag to re-register after upgrades (UTI declarations
> // may have changed in the new Info.plist).
> let bundlePath = Bundle.main.bundlePath
> let validPrefixes = ["/Applications/",
>                      NSHomeDirectory() + "/Applications/"]
> let isInstalled = validPrefixes.contains { bundlePath.hasPrefix($0) }
>
> if isInstalled,
>    ConfigStore.shared.lsRegisteredVersion != ExtensionRegistry.version {
>     selfRegisterWithLaunchServices()
>     ConfigStore.shared.lsRegisteredVersion = ExtensionRegistry.version
> }
> ```
>
> Note: the `isInstalled` check reuses the same logic as DMG-01. If
> the variable is already in scope from DMG-01's code, reuse it rather
> than recomputing.
>
> **ConfigStore addition:** Add a version-keyed registration property:
>
> - In `ConfigStore.swift`, add:
>   ```swift
>   var lsRegisteredVersion: String? = nil {
>       didSet { defaults.set(lsRegisteredVersion, forKey: "lsRegisteredVersion") }
>   }
>   ```
> - Initialize in `init()`:
>   ```swift
>   self.lsRegisteredVersion = defaults.string(forKey: "lsRegisteredVersion")
>   ```
> - Initialize in `init()`:
>   ```swift
>   self.lsRegistered = defaults.bool(forKey: "lsRegistered")
>   ```
>
> **`selfRegisterWithLaunchServices()`** method on AppDelegate:
>
> ```swift
> private func selfRegisterWithLaunchServices() {
>     let lsregister = "/System/Library/Frameworks/CoreServices.framework"
>         + "/Frameworks/LaunchServices.framework/Support/lsregister"
>     let bundlePath = Bundle.main.bundlePath
>     let task = Process()
>     task.executableURL = URL(fileURLWithPath: lsregister)
>     task.arguments = ["-f", bundlePath]
>     do {
>         try task.run()
>         task.waitUntilExit()
>         NSLog("Trampoline: registered with LaunchServices (exit %d)",
>               task.terminationStatus)
>     } catch {
>         NSLog("Trampoline: failed to run lsregister: %@",
>               error.localizedDescription)
>     }
> }
> ```
>
> This replaces the `make install` lsregister step for DMG installs.
> The `make install` step is kept for developer convenience (it still
> runs lsregister independently).
>
> **Constraints:** Compiles with `swiftc -O -warnings-as-errors`. No
> force-unwrapping. No TODO/FIXME. ConfigStore changes follow the
> existing `didSet` + UserDefaults pattern.

**Review criteria for `@code-review-opus` / `@code-review-gpt5`:**

> - lsregister only runs from `/Applications/` or `~/Applications/`
> - lsregister skipped when version matches `lsRegisteredVersion`
> - lsregister re-runs when version changes (upgrade)
> - lsregister called with `-f` flag (force registration)
> - Version flag only set AFTER successful `waitUntilExit` with
>   `terminationStatus == 0`
> - Process errors are logged, not fatal
> - ConfigStore property follows existing `didSet` pattern
> - No force-unwrapping

**Acceptance criteria:**

- Build compiles with zero warnings
- First launch from /Applications runs lsregister (check Console logs)
- Second launch does NOT run lsregister (same version)
- Launch from `/tmp/` does NOT run lsregister
- `defaults read com.maelos.trampoline lsRegisteredVersion` returns
  version string after first launch
- `trampoline status` shows extensions as REGISTERED after first launch
- After version bump: lsregister runs again on next launch

**Status:**

| Step                     | Status  | Notes |
| ------------------------ | ------- | ----- |
| Delegate to @code-writer | pending |       |
| Build verification       | pending |       |
| Smoke test               | pending |       |
| @code-review-opus        | pending |       |
| @code-review-gpt5        | pending |       |
| Fix review findings      | pending |       |
| Commit                   | pending | SHA:  |
| Plan updated             | pending |       |

---

### Phase 2: DMG Packaging

**Goal:** `make dmg` produces a `Trampoline-<version>.dmg` with the
app icon and an Applications folder alias, ready for distribution.

---

### DMG-03: Makefile DMG Target

**Estimated effort:** 30 minutes
**Dependencies:** DMG-01, DMG-02 (app must self-register since DMG
users don't run `make install`)
**Files:** `Makefile`, `.gitignore`

**Delegation prompt for `@code-writer`:**

> Add a `make dmg` target to Trampoline's Makefile.
>
> File: `/Users/rmk/projects/tools/trampoline/Makefile`
>
> **Current Makefile targets:** `all`, `clean`, `install`, `uninstall`
>
> **New target: `dmg`**
>
> Add a `dmg` target that depends on `all` and produces a DMG file:
>
> ```makefile
> VERSION := $(shell grep -o 'version = "[^"]*"' Sources/ExtensionRegistry.swift | head -1 | sed 's/.*"\(.*\)"/\1/')
> DMG := Trampoline-$(VERSION).dmg
>
> .PHONY: all clean install uninstall dmg
>
> dmg: all
> 	@echo "Creating DMG..."
> 	codesign --force --deep --sign - Trampoline.app
> 	rm -f "$(DMG)"
> 	create-dmg \
> 		--volname "Trampoline" \
> 		--volicon Trampoline.app/Contents/Resources/AppIcon.icns \
> 		--window-pos 200 120 \
> 		--window-size 600 400 \
> 		--icon-size 128 \
> 		--icon "Trampoline.app" 150 190 \
> 		--hide-extension "Trampoline.app" \
> 		--app-drop-link 450 190 \
> 		"$(DMG)" \
> 		Trampoline.app
> 	@echo "Created $(DMG)"
> ```
>
> **Note:** `create-dmg` requires the source argument to be a
> directory, but when given a `.app` bundle it treats it as the source
> folder contents. We need to pass the app itself. Looking at
> `create-dmg` docs: the source_folder argument copies ALL contents
> into the DMG. So we should create a staging directory:
>
> ```makefile
> dmg: all
> 	@command -v create-dmg >/dev/null 2>&1 || \
> 		{ echo "Error: create-dmg not found. Install with: brew install create-dmg"; exit 1; }
> 	@echo "Codesigning..."
> 	codesign --force --deep --sign - Trampoline.app
> 	@echo "Creating DMG..."
> 	rm -f "$(DMG)"
> 	rm -rf dmg-staging
> 	mkdir dmg-staging
> 	ditto Trampoline.app dmg-staging/Trampoline.app
> 	create-dmg \
> 		--volname "Trampoline" \
> 		--window-pos 200 120 \
> 		--window-size 600 400 \
> 		--icon-size 128 \
> 		--icon "Trampoline.app" 150 190 \
> 		--hide-extension "Trampoline.app" \
> 		--app-drop-link 450 190 \
> 		"$(DMG)" \
> 		dmg-staging/ \
> 		|| test $$? -eq 2
> 	rm -rf dmg-staging
> 	@echo "Created $(DMG)"
> ```
>
> Note: `--volicon` is deliberately omitted. The AppIcon.icns in the
> bundle skeleton may not exist in all build environments, and the
> default DMG volume icon is acceptable for v1. The `|| test $$? -eq 2`
> handles the case where `create-dmg` returns exit code 2 (Finder
> cosmetics failed but DMG was created successfully).
>
> **Also update `clean`** to remove DMG artifacts:
>
> ```makefile
> clean:
> 	rm -f $(BINARY)
> 	rm -f Trampoline-*.dmg
> 	rm -rf dmg-staging
> ```
>
> **Also update `.gitignore`** at
> `/Users/rmk/projects/tools/trampoline/.gitignore` to ignore:
>
> ```
> Trampoline-*.dmg
> dmg-staging/
> ```
>
> Read the current Makefile and .gitignore before making changes.
>
> **Constraints:** The `VERSION` extraction must work with the current
> `ExtensionRegistry.swift` which has `static let version = "1.0.0"`
> (or similar). Test the grep/sed pipeline. If the version format
> changes, this will break — but that's acceptable for now.

**Review criteria for `@code-review-opus` / `@code-review-gpt5`:**

> - `dmg` target depends on `all` (builds before packaging)
> - Codesigning happens before DMG creation (DMG contents are read-only)
> - Staging directory is created and cleaned up
> - `create-dmg` flags produce a reasonable layout (app on left,
>   Applications alias on right)
> - `clean` removes DMG artifacts
> - `.gitignore` excludes DMGs and staging directory
> - VERSION extraction works with the actual ExtensionRegistry.swift

**Acceptance criteria:**

- Build compiles with zero warnings
- `make dmg` produces `Trampoline-<version>.dmg`
- Opening the DMG shows Trampoline.app and an Applications folder alias
- Dragging the app to Applications works
- `make clean` removes the DMG and staging directory
- `.gitignore` excludes DMG files

**Status:**

| Step                     | Status  | Notes |
| ------------------------ | ------- | ----- |
| Delegate to @code-writer | pending |       |
| Build verification       | pending |       |
| Smoke test               | pending |       |
| @code-review-opus        | pending |       |
| @code-review-gpt5        | pending |       |
| Fix review findings      | pending |       |
| Commit                   | pending | SHA:  |
| Plan updated             | pending |       |

---

## Commit Protocol

**Format:** Conventional Commits

| Task   | Commit Message                                                 |
| ------ | -------------------------------------------------------------- |
| DMG-01 | `feat(install): move-to-Applications check on first launch`    |
| DMG-02 | `feat(install): self-register with lsregister on first launch` |
| DMG-03 | `build(dmg): add make dmg target for distributable disk image` |

---

## File Impact Summary

| File                          | Task(s)        | Purpose                                       |
| ----------------------------- | -------------- | --------------------------------------------- |
| `Sources/TrampolineApp.swift` | DMG-01, DMG-02 | Move-to-Applications check, lsregister call   |
| `Sources/ConfigStore.swift`   | DMG-01, DMG-02 | `suppressMovePrompt`, `lsRegisteredVersion`   |
| `Makefile`                    | DMG-03         | `dmg` target, `clean` update, VERSION extract |
| `.gitignore`                  | DMG-03         | Exclude DMGs and staging directory            |

---

## Risk Register

| Risk                                                   | Likelihood | Impact | Mitigation                                                                                             |
| ------------------------------------------------------ | ---------- | ------ | ------------------------------------------------------------------------------------------------------ | --- | --------------------------- |
| `create-dmg` not installed on build machine            | Medium     | Low    | `dmg` target is optional; `all` and `install` still work. Document the dep.                            |
| File copy to /Applications fails (permissions)         | Low        | Medium | Show error alert with instructions to drag manually                                                    |
| `lsregister` path changes in future macOS              | Very Low   | Medium | Log the error; app still works, just UTIs may not be registered                                        |
| User runs app from DMG mount without moving            | Medium     | High   | DMG-01 detects `/Volumes/` prefix and forces move-or-quit                                              |
| VERSION extraction breaks if format changes            | Low        | Low    | DMG build fails visibly; easy to fix the regex                                                         |
| Gatekeeper quarantine on DMG-downloaded app            | Medium     | Medium | Ad-hoc signing doesn't pass Gatekeeper. Users may need right-click → Open. Document in README.         |
| `/Applications/Trampoline.app` owned by root from sudo | Low        | Medium | `removeItem` may fail. Atomic replace with temp file mitigates; error alert shows manual instructions. |
| `create-dmg` returns exit code 2 (Finder cosmetics)    | Medium     | Low    | Handled with `                                                                                         |     | test $$? -eq 2` in Makefile |

---

## Out of Scope

| Item                                    | Rationale                                                                                        |
| --------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Custom DMG background image             | Polish item, not necessary for v1. Can be added later.                                           |
| Notarization / Developer ID codesigning | Requires Apple Developer account. Ad-hoc signing is sufficient for personal/GitHub distribution. |
| Auto-update mechanism (Sparkle, etc.)   | Separate feature, out of scope for packaging.                                                    |
| Homebrew cask publication               | Draft exists at `trampoline.rb`. Separate from DMG packaging.                                    |
| GitHub Releases automation              | Can be added later with `gh release create` + DMG upload.                                        |

---

## Post-Completion Checklist

- [ ] `make clean && make all` builds cleanly
- [ ] `make dmg` produces a valid DMG
- [ ] DMG opens, shows app + Applications alias
- [ ] Drag to Applications works
- [ ] First launch from /Applications: lsregister runs, settings opens
- [ ] Second launch: no lsregister, no move alert
- [ ] Running from DMG mount shows forced move alert
- [ ] CLI mode unaffected (`trampoline status`)
- [ ] DRY verification checklist passes
- [ ] No TODO/FIXME in source
- [ ] All status tables marked done with commit SHAs

---

## New User Install Flow (After Implementation)

```
1. Download Trampoline-1.0.0.dmg
2. Double-click to mount
3. Drag Trampoline.app → Applications (shown in DMG window)
4. Eject the DMG
5. Launch Trampoline.app from /Applications (or Spotlight)
6. (First launch) App self-registers with lsregister
7. (First launch) Settings window opens, user picks their editor
8. Done — all developer files now open in the chosen editor
```

No terminal commands required. No `make install`. No sudo.
