# Use Cases

## Use Case Map

Each use case references a specific flow in [03-flows.md](03-flows.md).

### UC-1: First Run

**Actor:** User
**Trigger:** User installs Trampoline.app and launches it for the first time
**Precondition:** No editor preference is configured
**Flow:** [F-01: First Run Setup](#f-01)

**Steps:**

1. User drags Trampoline.app to `/Applications`
2. User double-clicks Trampoline.app
3. Trampoline detects no editor is configured (`firstRunComplete == false`)
4. Settings window opens with the General tab focused
5. EditorDetector scans for installed editors
6. User selects their preferred editor from the dropdown
7. Trampoline saves the editor preference
8. Trampoline offers to claim unclaimed extensions
9. User confirms; Trampoline calls `LSSetDefaultRoleHandlerForContentType` for
   each extension that has no existing handler (zero dialogs for these)
10. For contested extensions, Trampoline shows which apps currently own them
    and offers to claim them (may trigger dialogs)
11. First run marked complete; settings window remains open

**Postcondition:** Editor is configured. Trampoline is the handler for
unclaimed extensions. User can close settings and Trampoline runs as a
background agent.

---

### UC-2: Open a File via Finder

**Actor:** User
**Trigger:** User double-clicks a developer file (e.g., `.rs`, `.go`, `.tsx`)
**Precondition:** Trampoline is the registered handler for that extension
**Flow:** [F-02: File Forwarding](#f-02)

**Steps:**

1. User double-clicks `main.rs` in Finder
2. macOS launches Trampoline (or sends Apple Event if already running)
3. `application(_:open:)` is called with the file URL
4. FileForwarder reads `editorBundleID` from ConfigStore
5. FileForwarder calls `NSWorkspace.shared.open([url], withApplicationAt: ...)`
6. The editor opens with `main.rs`
7. Trampoline remains running in the background

**Postcondition:** File is open in the user's editor. Trampoline is ready for
the next file open event.

---

### UC-3: Open Multiple Files

**Actor:** User
**Trigger:** User selects multiple files in Finder and presses Enter / Open With
**Precondition:** Trampoline is the registered handler
**Flow:** [F-02: File Forwarding](#f-02) (batched)

**Steps:**

1. User selects 5 files in Finder, right-clicks, Open With > Trampoline
2. `application(_:open:)` is called with all 5 file URLs
3. FileForwarder opens all 5 URLs in a single `NSWorkspace.open` call
4. The editor opens with all 5 files

**Postcondition:** All files open in the editor.

---

### UC-4: Change Editor

**Actor:** User
**Trigger:** User wants to switch from Zed to VSCode
**Precondition:** Trampoline is installed and configured
**Flow:** [F-03: Change Editor](#f-03)

**Steps:**

1. User opens Trampoline settings (via menu bar icon or re-launching the app)
2. User selects a different editor from the dropdown
3. Trampoline saves the new editor preference
4. No re-registration needed -- Trampoline is still the handler; it just
   forwards to a different editor now

**Postcondition:** Future file opens go to the new editor. No dialogs.

---

### UC-5: Claim Contested Extensions

**Actor:** User
**Trigger:** Some extensions are handled by Xcode, TextEdit, or another app
**Precondition:** Trampoline is installed
**Flow:** [F-04: Claim Extensions](#f-04)

**Steps:**

1. User opens the Extensions tab in settings
2. User sees which extensions are "Claimed" (by Trampoline), "Other App"
   (e.g., Xcode), or "Unclaimed"
3. User clicks "Claim All" or selects specific extensions
4. For unclaimed extensions: Trampoline becomes handler silently
5. For contested extensions: `LSSetDefaultRoleHandlerForContentType` is called,
   which may trigger a macOS confirmation dialog per extension
6. Status updates in the table

**Postcondition:** Selected extensions now route through Trampoline.

---

### UC-6: Use CLI to Set Editor

**Actor:** Developer (terminal user)
**Trigger:** User prefers command-line configuration
**Precondition:** CLI symlink installed
**Flow:** [F-05: CLI Operations](#f-05)

**Steps:**

1. `trampoline editor zed` -- sets Zed as the default editor
2. `trampoline status` -- shows extension handler mapping
3. `trampoline claim --all` -- claims all extensions

**Postcondition:** Same result as GUI operations.

---

### UC-7: Install CLI

**Actor:** Developer
**Trigger:** User wants the `trampoline` command available
**Precondition:** Trampoline.app is in `/Applications`
**Flow:** [F-06: CLI Installation](#f-06)

**Steps:**

1. User opens Settings > General tab
2. User clicks "Install CLI" button
3. Trampoline creates symlink: `/usr/local/bin/trampoline` -> app binary
4. Or via terminal: `trampoline install-cli`

**Postcondition:** `trampoline` command is available in `$PATH`.

---

### UC-8: Uninstall

**Actor:** User
**Trigger:** User no longer wants Trampoline
**Precondition:** Trampoline is installed
**Flow:** [F-07: Uninstall](#f-07)

**Steps:**

1. User drags Trampoline.app to Trash
2. macOS automatically unregisters Trampoline's `CFBundleDocumentTypes`
3. Extensions revert to their previous handlers (macOS handles this)
4. Optionally: `trampoline uninstall` before deletion to clean up CLI symlink
   and preferences

**Postcondition:** All extensions revert to their pre-Trampoline handlers.

---

### UC-9: No Editor Configured, File Opened

**Actor:** User
**Trigger:** File is double-clicked but no editor preference exists
**Precondition:** Trampoline is the handler but editor is not configured
**Flow:** [F-08: Missing Editor Recovery](#f-08)

**Steps:**

1. User double-clicks a `.go` file
2. Trampoline receives the open event
3. FileForwarder finds `editorBundleID == nil`
4. Trampoline shows settings window with a banner: "Choose an editor to
   open your files"
5. User selects an editor
6. The original file is forwarded to the now-configured editor
7. Future files open normally

**Postcondition:** Editor is configured; the file that triggered this flow is
open in the editor.

---

### UC-10: Editor Not Installed

**Actor:** User
**Trigger:** File is opened but the configured editor has been uninstalled
**Precondition:** `editorBundleID` is set but the app is gone
**Flow:** [F-09: Editor Not Found Recovery](#f-09)

**Steps:**

1. User double-clicks a file
2. FileForwarder tries to resolve `editorBundleID` via `NSWorkspace`
3. Resolution fails (app not found)
4. Trampoline shows settings window with a warning: "Zed is no longer
   installed. Choose a different editor."
5. User selects a new editor
6. The original file is forwarded

**Postcondition:** Editor preference updated; file opened.

---

## Use Case Priority Matrix

```mermaid
quadrantChart
    title Use Case Priority
    x-axis Low Frequency --> High Frequency
    y-axis Low Impact --> High Impact
    quadrant-1 Must have
    quadrant-2 Important
    quadrant-3 Nice to have
    quadrant-4 Can defer
    UC-2 File forwarding: [0.95, 0.95]
    UC-1 First run: [0.15, 0.90]
    UC-4 Change editor: [0.30, 0.70]
    UC-5 Claim extensions: [0.25, 0.80]
    UC-6 CLI set editor: [0.40, 0.60]
    UC-9 No editor recovery: [0.10, 0.85]
    UC-10 Editor gone recovery: [0.05, 0.75]
    UC-3 Multi-file: [0.60, 0.50]
    UC-7 Install CLI: [0.10, 0.40]
    UC-8 Uninstall: [0.05, 0.30]
```
