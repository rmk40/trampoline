# Wireframes

All screens use SwiftUI with the system appearance (light/dark follows macOS
settings). Window style is `.titleBar` with toolbar-style tab navigation
(like System Settings on macOS 13+).

## Window Dimensions

- Default: 640 x 480
- Minimum: 540 x 400
- Maximum: 800 x 600

## Tab Bar

Three tabs in the toolbar, icon + label style (like System Settings):

| Tab        | Icon            | Label      |
| ---------- | --------------- | ---------- |
| General    | `gearshape`     | General    |
| Extensions | `doc.plaintext` | Extensions |
| About      | `info.circle`   | About      |

---

## Screen 1: General Tab

The primary configuration screen. Clean, minimal layout.

```
+------------------------------------------------------------------+
|  [General]    [Extensions]    [About]                       [x]  |
+------------------------------------------------------------------+
|                                                                  |
|  Default Editor                                                  |
|  +------------------------------------------------------------+  |
|  |  [Zed icon]  Zed                                      [v]  |  |
|  +------------------------------------------------------------+  |
|                                                                  |
|  +------------------------------------------------------------+  |
|  |  (i) When you open a developer file, Trampoline will       |  |
|  |      forward it to Zed.                                    |  |
|  +------------------------------------------------------------+  |
|                                                                  |
|  +--------------------------+  +--------------------------+      |
|  | [checkmark] Show in      |  | [button] Install CLI...  |      |
|  |   menu bar               |  |                          |      |
|  +--------------------------+  +--------------------------+      |
|                                                                  |
|  Extension Status                                                |
|  +------------------------------------------------------------+  |
|  |  84 managed  |  60 claimed  |  15 other  |  9 unclaimed   |  |
|  +------------------------------------------------------------+  |
|  |         [  Claim Unclaimed (9)  ]   [ Claim All (24) ]     |  |
|  +------------------------------------------------------------+  |
|                                                                  |
+------------------------------------------------------------------+
```

### Elements

**Editor Picker**: A dropdown (`Picker`) populated by `EditorDetector`. Shows
the app icon, display name, and bundle ID in smaller text. The dropdown
includes all detected editors plus an "Other..." option that opens a file
browser filtered to `.app` bundles.

**Info Banner**: Contextual message below the picker:

- Normal: "When you open a developer file, Trampoline will forward it to {editor}."
- First run: "Choose an editor to get started."
- Editor missing: "**{editor} is no longer installed.** Choose a different editor."
- Pending files: "**{N} file(s) waiting.** Choose an editor to open them."

**Menu Bar Toggle**: Checkbox for `showMenuBarIcon`. When unchecked, the app
is completely invisible (can only be accessed by re-launching or via CLI).

**Install CLI Button**: Calls the symlink creation flow. Shows "CLI Installed"
with a checkmark if the symlink already exists.

**Extension Status Bar**: A horizontal segmented summary showing counts.
Clicking opens the Extensions tab.

**Claim Buttons**:

- "Claim Unclaimed (N)" -- claims only extensions with no current handler
  (zero dialogs)
- "Claim All (N)" -- claims unclaimed + contested extensions (may trigger
  dialogs for contested ones)

---

## Screen 1a: General Tab - First Run State

```
+------------------------------------------------------------------+
|  [General]    [Extensions]    [About]                       [x]  |
+------------------------------------------------------------------+
|                                                                  |
|  +------------------------------------------------------------+  |
|  |  Welcome to Trampoline                                     |  |
|  |                                                            |  |
|  |  Trampoline makes developer files open in your preferred   |  |
|  |  code editor. Choose your editor below to get started.     |  |
|  +------------------------------------------------------------+  |
|                                                                  |
|  Default Editor                                                  |
|  +------------------------------------------------------------+  |
|  |  Select an editor...                                  [v]  |  |
|  +------------------------------------------------------------+  |
|  |    [Zed icon]   Zed                                        |  |
|  |    [VS icon]    Visual Studio Code                         |  |
|  |    [Cursor]     Cursor                                     |  |
|  |    [Sublime]    Sublime Text                               |  |
|  |    [folder]     Other...                                   |  |
|  +------------------------------------------------------------+  |
|                                                                  |
|                                                                  |
|                                                                  |
|                                                                  |
|                                                                  |
+------------------------------------------------------------------+
```

In first-run state, only the welcome banner and editor picker are shown.
Other controls appear after the editor is selected.

---

## Screen 1b: General Tab - Editor Missing Warning

```
+------------------------------------------------------------------+
|  [General]    [Extensions]    [About]                       [x]  |
+------------------------------------------------------------------+
|                                                                  |
|  Default Editor                                                  |
|  +------------------------------------------------------------+  |
|  |  [?]  Zed (not installed)                             [v]  |  |
|  +------------------------------------------------------------+  |
|                                                                  |
|  +------------------------------------------------------------+  |
|  |  (!) Zed is no longer installed. Choose a different        |  |
|  |      editor, or Trampoline can't forward files.            |  |
|  +------------------------------------------------------------+  |
|                                                                  |
|  ...                                                             |
+------------------------------------------------------------------+
```

---

## Screen 2: Extensions Tab

A searchable, sortable table of all managed extensions.

```
+------------------------------------------------------------------+
|  [General]    [Extensions]    [About]                       [x]  |
+------------------------------------------------------------------+
|                                                                  |
|  [Search: ____________]                [Claim All]               |
|                                                                  |
|  +----+-------------+----------------------+-----------+------+  |
|  |    | Extension   | Current Handler      | Status    |      |  |
|  +----+-------------+----------------------+-----------+------+  |
|  | [] | .ts         | Trampoline           | Claimed   |      |  |
|  | [] | .tsx        | Trampoline           | Claimed   |      |  |
|  | [] | .rs         | Trampoline           | Claimed   |      |  |
|  | [] | .go         | Trampoline           | Claimed   |      |  |
|  | [] | .json       | Xcode                | Other     |      |  |
|  | [] | .xml        | Xcode                | Other     |      |  |
|  | [] | .py         | (none)               | Unclaimed |      |  |
|  | [] | .rb         | (none)               | Unclaimed |      |  |
|  | [] | .swift      | Xcode                | Other     |      |  |
|  | [] | .kt         | Trampoline           | Claimed   |      |  |
|  | [] | .vue        | Trampoline           | Claimed   |      |  |
|  | [] | .conf       | Trampoline           | Claimed   |      |  |
|  |    | ...         |                      |           |      |  |
|  +----+-------------+----------------------+-----------+------+  |
|                                                                  |
|  Selected: 0  |  [Claim Selected]  [Release Selected]            |
|                                                                  |
+------------------------------------------------------------------+
```

### Elements

**Search Field**: Filters the table by extension name.

**Table Columns**:

- **Checkbox**: Multi-select for batch operations
- **Extension**: The file extension (e.g., `.ts`, `.json`)
- **Current Handler**: The app currently registered as the handler. Shows
  the app's display name.
- **Status**: Color-coded badge:
  - **Claimed** (green) -- Trampoline is the handler
  - **Other** (orange) -- another app is the handler
  - **Unclaimed** (gray) -- no handler set

**Sorting**: Click column headers to sort. Default sort: Status (Other first,
then Unclaimed, then Claimed).

**Batch Actions**:

- "Claim Selected" -- claims checked extensions (LS API, may trigger dialogs)
- "Release Selected" -- removes Trampoline as handler, reverts to system
  default. Uses `LSSetDefaultRoleHandlerForContentType` with the previous
  handler's bundle ID (if known) or a system default.
- "Claim All" -- claims all non-Claimed extensions

---

## Screen 3: About Tab

```
+------------------------------------------------------------------+
|  [General]    [Extensions]    [About]                       [x]  |
+------------------------------------------------------------------+
|                                                                  |
|          [App Icon]                                              |
|          Trampoline                                              |
|          Version 1.0 (build 42)                                  |
|                                                                  |
|  +------------------------------------------------------------+  |
|  |  Trampoline registers itself as the default handler for    |  |
|  |  developer file extensions, then silently forwards files   |  |
|  |  to your preferred code editor.                            |  |
|  |                                                            |  |
|  |  No more clicking through dozens of dialogs to set your    |  |
|  |  editor as the default for every file type.                |  |
|  +------------------------------------------------------------+  |
|                                                                  |
|  +--------------------+  +--------------------+                  |
|  |  [link] GitHub     |  |  [link] Report     |                  |
|  |   Repository       |  |   an Issue         |                  |
|  +--------------------+  +--------------------+                  |
|                                                                  |
|  License: MIT                                                    |
|                                                                  |
+------------------------------------------------------------------+
```

---

## Menu Bar

```
+---------------------------+
|  [T] Trampoline      |
+---------------------------+
|  Editor: Zed              |
|  84 extensions managed    |
|  ----------------------   |
|  Settings...              |
|  ----------------------   |
|  Quit Trampoline          |
+---------------------------+
```

The menu bar icon is a small "T" glyph or a trampoline-inspired SF Symbol.
The menu is minimal -- just status info, settings access, and quit.

---

## CLI Interface

The CLI shares the same binary as the GUI app. It detects CLI mode when
invoked as `/usr/local/bin/trampoline` (symlink) or with recognized
subcommands.

### Help Output

```
$ trampoline --help
Trampoline - Developer file handler for macOS

USAGE:
    trampoline <command> [options]

COMMANDS:
    editor [name|bundle-id]    Get or set the default editor
    status                     Show extension handler status
    claim [--all]              Claim extensions as Trampoline
    release [--all]            Release extensions back to system
    install-cli                Create /usr/local/bin/trampoline symlink
    uninstall                  Remove CLI, clear preferences

OPTIONS:
    -h, --help                 Show this help
    -v, --version              Show version

EXAMPLES:
    trampoline editor                    Show current editor
    trampoline editor zed                Set Zed as default
    trampoline editor com.microsoft.VSCode  Set by bundle ID
    trampoline status                    Show all extensions
    trampoline status --json             Machine-readable output
    trampoline claim                     Claim unclaimed only
    trampoline claim --all               Claim all (may show dialogs)
```

### Status Output (Detailed)

```
$ trampoline status

Trampoline v1.0
Editor: Zed (dev.zed.Zed)

CLAIMED (60)
  .ts .tsx .jsx .rs .go .zig .nim .kt .kts .scala .sc .groovy .gvy
  .cs .fs .fsi .fsx .dart .lua .coffee .ex .exs .elm .hs .lhs .ml
  .mli .tf .tfvars .hcl .toml .nix .dhall .graphql .gql .proto
  .prisma .sass .scss .less .styl .jade .pug .ejs .hbs .handlebars
  .mustache .twig .jinja .jinja2 .j2 .mdx .ipynb .vue .svelte .astro
  .r .R .mts .cts .env .conf

OTHER (15)
  .json       Xcode
  .xml        Xcode
  .yaml       Xcode
  .yml        Xcode
  .py         Xcode
  .rb         Xcode
  .swift      Xcode
  .c          Xcode
  .h          Xcode
  .m          Xcode
  .sh         Terminal
  .bash       Terminal
  .zsh        Terminal
  .sql        Sequel Pro
  .md         MacDown

UNCLAIMED (9)
  .tsv .lock .gitignore .gitattributes .editorconfig .dockerfile
  .makefile .gemspec .cmake
```
