# Flow Diagrams

Each flow corresponds to a use case in [02-use-cases.md](02-use-cases.md).

## F-01: First Run Setup

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant App as Trampoline
    participant Config as ConfigStore
    participant Detect as EditorDetector
    participant LS as LaunchServices
    participant GUI as SettingsWindow

    User->>App: Launch Trampoline.app
    App->>Config: Read firstRunComplete
    Config-->>App: false

    App->>GUI: Show settings window
    App->>Detect: Scan for installed editors
    Detect-->>GUI: List of editors

    User->>GUI: Select editor (e.g., Zed)
    GUI->>Config: Save editorBundleID

    GUI->>GUI: Show extension status table
    Note over GUI: Unclaimed extensions<br/>highlighted

    User->>GUI: Click "Claim Unclaimed"

    loop Each unclaimed extension
        GUI->>LS: LSSetDefaultRole...<br/>(silent, no dialog)
    end

    GUI->>Config: Save claimedExtensions
    GUI->>Config: Set firstRunComplete = true
    GUI-->>User: Setup complete
```

## F-02: File Forwarding (Core Loop)

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Finder as macOS Finder
    participant App as Trampoline
    participant Fwd as FileForwarder
    participant Config as ConfigStore
    participant WS as NSWorkspace
    participant Editor as User's Editor

    User->>Finder: Double-click main.rs
    Finder->>App: application(_:open: [main.rs])
    App->>Fwd: Forward file URLs

    Fwd->>Config: Read editorBundleID
    Config-->>Fwd: dev.zed.Zed

    Fwd->>WS: urlForApplication(bundleID)
    WS-->>Fwd: /Applications/Zed.app

    Fwd->>WS: open([main.rs],<br/>withApplicationAt: Zed.app)
    WS->>Editor: Open main.rs

    Note over App: Trampoline stays<br/>running in background
```

## F-03: Change Editor

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Menu as Menu Bar Icon
    participant GUI as SettingsWindow
    participant Config as ConfigStore
    participant Detect as EditorDetector

    User->>Menu: Click menu bar icon
    Menu->>GUI: Show settings window

    GUI->>Detect: Refresh installed editors
    Detect-->>GUI: Updated editor list

    User->>GUI: Select VSCode from dropdown
    GUI->>Config: Save editorBundleID =<br/>com.microsoft.VSCode

    Note over GUI: "Default editor: VSCode"<br/>No re-registration needed
```

## F-04: Claim Extensions

```mermaid
flowchart TB
    Start["User opens<br/>Extensions tab"]
    Scan["Scan all managed<br/>extensions"]
    Categorize{"For each extension"}

    Unclaimed["Status: Unclaimed<br/>(no handler set)"]
    Ours["Status: Trampoline<br/>(already claimed)"]
    Other["Status: Other App<br/>(e.g., Xcode)"]

    ClaimUnclaimed["Claim silently<br/>(zero dialogs)"]
    ClaimOther["Claim via LS API<br/>(may show dialog)"]
    Skip["No action needed"]

    Start --> Scan --> Categorize
    Categorize -->|"No handler"| Unclaimed
    Categorize -->|"Trampoline"| Ours
    Categorize -->|"Other app"| Other

    Unclaimed --> ClaimUnclaimed
    Ours --> Skip
    Other --> ClaimOther
```

### Extension Claiming Detail

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant GUI as Extensions Tab
    participant LS as LaunchServices
    participant API as LSSetDefaultRole...

    GUI->>LS: Query handler for each ext
    LS-->>GUI: Handler status per ext

    User->>GUI: Click "Claim All"

    loop Unclaimed extensions
        GUI->>API: Set handler (Trampoline)
        API-->>GUI: Success (no dialog)
    end

    alt Contested extensions exist
        GUI-->>User: "N extensions are owned<br/>by other apps. Claim?"
        User->>GUI: Confirm

        loop Contested extensions
            GUI->>API: Set handler (Trampoline)
            Note over API: macOS may show<br/>confirmation dialog
            API-->>GUI: Success
        end
    end

    GUI-->>User: All extensions claimed
```

## F-05: CLI Operations

```mermaid
flowchart TB
    Invoke["trampoline <command>"]
    Parse["Parse argv"]

    EditorGet["trampoline editor"]
    EditorSet["trampoline editor zed"]
    Status["trampoline status"]
    Claim["trampoline claim"]
    InstallCLI["trampoline install-cli"]
    Uninstall["trampoline uninstall"]

    ReadConfig["Read ConfigStore"]
    WriteConfig["Write ConfigStore"]
    QueryLS["Query LaunchServices"]
    SetLS["Set via LS API"]
    Symlink["Create symlink"]
    Cleanup["Remove symlink +<br/>clear UserDefaults"]

    PrintResult["Print to stdout"]
    ExitOK["exit(0)"]
    ExitErr["exit(1)"]

    Invoke --> Parse
    Parse -->|"editor"| EditorGet
    Parse -->|"editor <name>"| EditorSet
    Parse -->|"status"| Status
    Parse -->|"claim"| Claim
    Parse -->|"install-cli"| InstallCLI
    Parse -->|"uninstall"| Uninstall

    EditorGet --> ReadConfig --> PrintResult --> ExitOK
    EditorSet --> WriteConfig --> PrintResult
    Status --> QueryLS --> PrintResult
    Claim --> SetLS --> PrintResult
    InstallCLI --> Symlink --> PrintResult
    Uninstall --> Cleanup --> PrintResult
```

### CLI Output Examples

```
$ trampoline editor
dev.zed.Zed (Zed)

$ trampoline editor vscode
Default editor set to: Visual Studio Code (com.microsoft.VSCode)

$ trampoline status
Extension  Handler              Status
.ts        com.maelos.trampoline  Claimed
.tsx       com.maelos.trampoline  Claimed
.rs        com.maelos.trampoline  Claimed
.json      com.apple.Xcode        Other (Xcode)
.py        (none)                 Unclaimed
...
84 extensions: 60 claimed, 15 other, 9 unclaimed

$ trampoline claim --all
Claiming 9 unclaimed extensions... done (no dialogs)
Claiming 15 contested extensions...
  .json (Xcode) -> Trampoline ... ok
  .xml (Xcode) -> Trampoline ... ok
  ...
24 extensions claimed.

$ trampoline install-cli
Created symlink: /usr/local/bin/trampoline
```

## F-06: CLI Installation

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Shell as Terminal
    participant App as Trampoline (CLI)
    participant FS as File System

    User->>Shell: trampoline install-cli
    Note over Shell: Or: from Settings GUI

    App->>FS: Check /usr/local/bin exists
    alt Directory exists
        App->>FS: Create symlink<br/>/usr/local/bin/trampoline<br/>-> .../Trampoline.app/.../Trampoline
        FS-->>App: Success
        App-->>User: "CLI installed"
    else Permission denied
        App-->>User: "Run with sudo or<br/>check /usr/local/bin permissions"
    end
```

## F-07: Uninstall

```mermaid
flowchart TB
    A["User deletes<br/>Trampoline.app"]
    B["macOS unregisters<br/>CFBundleDocumentTypes"]
    C["Extensions revert to<br/>previous handlers"]
    D["UserDefaults remain<br/>(harmless)"]

    A --> B --> C
    A --> D

    E["Optional: trampoline uninstall"]
    F["Remove CLI symlink"]
    G["Clear UserDefaults"]
    H["Delete app"]

    E --> F --> G --> H
```

## F-08: Missing Editor Recovery

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Finder
    participant App as Trampoline
    participant Fwd as FileForwarder
    participant Config as ConfigStore
    participant GUI as SettingsWindow

    User->>Finder: Double-click file.go
    Finder->>App: application(_:open: [file.go])
    App->>Fwd: Forward file URLs

    Fwd->>Config: Read editorBundleID
    Config-->>Fwd: nil (not configured)

    Fwd->>App: Store pending files
    App->>GUI: Show settings with banner:<br/>"Choose an editor to open files"

    User->>GUI: Select Zed
    GUI->>Config: Save editorBundleID

    GUI->>Fwd: Retry pending files
    Fwd->>Fwd: Forward file.go to Zed
```

## F-09: Editor Not Found Recovery

```mermaid
sequenceDiagram
    autonumber
    actor User
    participant Finder
    participant App as Trampoline
    participant Fwd as FileForwarder
    participant WS as NSWorkspace
    participant GUI as SettingsWindow

    User->>Finder: Double-click file.rs
    Finder->>App: application(_:open: [file.rs])
    App->>Fwd: Forward file URLs

    Fwd->>WS: urlForApplication("dev.zed.Zed")
    WS-->>Fwd: nil (not installed)

    Fwd->>App: Store pending files
    App->>GUI: Show settings with warning:<br/>"Zed is no longer installed"

    User->>GUI: Select VSCode
    GUI->>Fwd: Retry pending files
    Fwd->>Fwd: Forward file.rs to VSCode
```

## F-10: App Launch Mode Decision

```mermaid
flowchart TB
    Launch["Trampoline.app<br/>launched"]
    CheckCLI{"argv contains<br/>subcommand?"}
    CheckFiles{"Launched with<br/>file URLs?"}
    CheckRunning{"Already<br/>running?"}

    CLI["CLI Mode:<br/>Execute command,<br/>exit"]
    Forward["Forward Mode:<br/>Send files to editor"]
    Settings["GUI Mode:<br/>Show settings window"]
    BringFront["Bring existing<br/>window to front"]

    Launch --> CheckCLI
    CheckCLI -->|"Yes"| CLI
    CheckCLI -->|"No"| CheckFiles
    CheckFiles -->|"Yes"| Forward
    CheckFiles -->|"No"| CheckRunning
    CheckRunning -->|"Yes"| BringFront
    CheckRunning -->|"No"| Settings
```
