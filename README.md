# Trampoline

A macOS app that makes developer files open in your preferred code editor -- without clicking through dozens of confirmation dialogs.

## What It Does

macOS has no good way to set a single editor as the default handler for all developer file extensions. The `LSSetDefaultRoleHandlerForContentType` API (used by tools like `duti`) triggers a confirmation dialog for each extension. Directly editing the LaunchServices database corrupts it.

Trampoline solves this with a **trampoline pattern**: it registers itself as the default handler for 85 developer file extensions via `CFBundleDocumentTypes` in its `Info.plist`. When you double-click a file, Trampoline receives the open event and immediately forwards it to your configured editor. Trampoline is invisible -- you see the file open in your editor as if it were the default handler all along.

## How It Works

1. **Registration.** Trampoline's `Info.plist` declares `CFBundleDocumentTypes` for 85 file extensions. For extensions with no existing system UTI (like `.rs`, `.vue`, `.zig`), Trampoline exports custom UTIs and claims them with `LSHandlerRank = Owner`. For extensions already claimed by system apps (like `.json`, `.py`, `.sh`), it declares `LSHandlerRank = Alternate` to avoid conflicts until you explicitly claim them.

2. **Forwarding.** When macOS sends an "open file" event to Trampoline, it reads your configured editor from preferences and opens the file in that editor via `NSWorkspace`. Trampoline never displays the file itself.

3. **Claiming.** You choose which extensions Trampoline handles. Extensions with no current handler can be claimed silently. Extensions owned by another app (like Xcode) require a one-time confirmation dialog from macOS.

## Installation

### Homebrew (coming soon)

```sh
brew install --cask trampoline
```

> The Homebrew cask is not yet published. In the meantime, download from [GitHub Releases](https://github.com/maelos/trampoline/releases).

### Manual Download

1. Download `Trampoline-<version>.zip` from [GitHub Releases](https://github.com/maelos/trampoline/releases).
2. Unzip and move `Trampoline.app` to `/Applications`.
3. Open `Trampoline.app` once to register its file type declarations with Launch Services.

### Build from Source

Requires Xcode Command Line Tools and macOS 14.0 (Sonoma) or later.

```sh
git clone https://github.com/maelos/trampoline.git
cd trampoline
make all        # Compile the app bundle
make install    # Copy to /Applications, register with Launch Services, create CLI symlink
```

Other targets:

| Command          | Description                                                                                     |
| ---------------- | ----------------------------------------------------------------------------------------------- |
| `make all`       | Compile `Trampoline.app/Contents/MacOS/Trampoline`                                              |
| `make install`   | Copy to `/Applications`, register with `lsregister`, symlink CLI to `/usr/local/bin/trampoline` |
| `make clean`     | Remove the compiled binary                                                                      |
| `make uninstall` | Remove the app, CLI symlink, and preferences                                                    |

## Usage

### GUI

Open `Trampoline.app` to access the settings window:

- **General tab** -- Pick your default editor from a dropdown of detected editors. View extension status (claimed, unclaimed, owned by another app). Claim unclaimed extensions silently, or claim all extensions (may trigger macOS confirmation dialogs for contested ones).
- **Extensions tab** -- Searchable table of all 85 managed extensions. See which app currently handles each one. Select individual extensions to claim or release.
- **About tab** -- Version info and links.

An optional menu bar icon shows your current editor and extension count.

### CLI

The CLI is built into the app binary. After installation, it is available at `/usr/local/bin/trampoline`. You can also create the symlink from the GUI (Settings > Install CLI) or by running:

```sh
trampoline install-cli
```

Full help output:

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

#### Set your editor

```sh
# By shorthand
trampoline editor zed

# By bundle ID
trampoline editor com.microsoft.VSCode

# Show current editor
trampoline editor
```

#### Check extension status

```sh
trampoline status
```

```
Trampoline v1.0
Editor: Zed (dev.zed.Zed)

CLAIMED (60)
  .ts .tsx .jsx .rs .go .zig .nim .kt .kts .scala .sc .groovy .gvy
  .cs .fs .fsi .fsx .dart .lua .coffee .ex .exs .elm .hs .lhs .ml
  .mli .tf .tfvars .hcl .toml .nix .dhall .graphql .gql .proto ...

OTHER (15)
  .json       Xcode
  .xml        Xcode
  .swift      Xcode
  .py         Xcode
  .sh         Terminal
  ...

UNCLAIMED (9)
  .tsv .lock .gitignore .gitattributes .editorconfig .dockerfile ...
```

#### Claim extensions

```sh
# Claim only unclaimed extensions (no dialogs)
trampoline claim

# Claim all extensions, including those owned by other apps
trampoline claim --all
```

## Managed Extensions

Trampoline manages 85 file extensions across 20 categories. Extensions with custom UTIs (marked with `*`) are claimed as primary handler. Extensions with system or dynamic UTIs are declared as alternate handler until you explicitly claim them.

### Languages

| Category   | Extensions                                    |
| ---------- | --------------------------------------------- |
| TypeScript | `.ts` `.mts` `.cts`                           |
| React      | `.tsx` `.jsx`                                 |
| Systems    | `.rs` `.go` `.zig` `.nim`                     |
| JVM        | `.kt` `.kts` `.scala` `.sc` `.groovy` `.gvy`  |
| .NET       | `.cs` `.fs` `.fsi` `.fsx`                     |
| Mobile     | `.dart`                                       |
| Scripting  | `.lua` `.coffee` `.py` `.rb`                  |
| Functional | `.ex` `.exs` `.elm` `.hs` `.lhs` `.ml` `.mli` |
| R          | `.r` `.R`                                     |

### Web and Markup

| Category       | Extensions                                                                              |
| -------------- | --------------------------------------------------------------------------------------- |
| Web frameworks | `.vue` `.svelte` `.astro`                                                               |
| Stylesheets    | `.sass` `.scss` `.less` `.styl`                                                         |
| Templates      | `.jade` `.pug` `.ejs` `.hbs` `.handlebars` `.mustache` `.twig` `.jinja` `.jinja2` `.j2` |
| Documents      | `.mdx` `.ipynb`                                                                         |

### Data and Config

| Category   | Extensions                                     |
| ---------- | ---------------------------------------------- |
| Data       | `.json` `.yaml` `.yml` `.xml` `.sql` `.tsv`    |
| Config/IaC | `.tf` `.tfvars` `.hcl` `.toml` `.nix` `.dhall` |
| Config     | `.env` `.conf` `.properties`                   |
| Schema     | `.graphql` `.gql` `.proto` `.prisma`           |

### Infrastructure and Tooling

| Category         | Extensions                     |
| ---------------- | ------------------------------ |
| Shell            | `.sh` `.bash` `.zsh`           |
| Build            | `.makefile` `.cmake` `.gradle` |
| Containers       | `.dockerfile`                  |
| Package managers | `.lock`                        |
| Git              | `.gitignore` `.gitattributes`  |
| Editor config    | `.editorconfig`                |
| Ruby             | `.gemspec`                     |
| Version control  | `.patch` `.diff`               |

## Supported Editors

Trampoline recognizes these editors by shorthand, bundle ID, or display name. You can also use any `.app` bundle not on this list by passing its bundle ID directly.

| Shorthand         | Bundle ID                       | Display Name       |
| ----------------- | ------------------------------- | ------------------ |
| `zed`             | `dev.zed.Zed`                   | Zed                |
| `vscode`          | `com.microsoft.VSCode`          | Visual Studio Code |
| `vscode-insiders` | `com.microsoft.VSCodeInsiders`  | VS Code Insiders   |
| `cursor`          | `com.todesktop.230313mzl4w4u92` | Cursor             |
| `sublime`         | `com.sublimetext.4`             | Sublime Text       |
| `sublime3`        | `com.sublimetext.3`             | Sublime Text 3     |
| `nova`            | `com.panic.Nova`                | Nova               |
| `bbedit`          | `com.barebones.bbedit`          | BBEdit             |
| `textmate`        | `com.macromates.TextMate`       | TextMate           |
| `webstorm`        | `com.jetbrains.WebStorm`        | WebStorm           |
| `intellij`        | `com.jetbrains.intellij`        | IntelliJ IDEA      |
| `fleet`           | `com.jetbrains.fleet`           | Fleet              |

Any JetBrains IDE (`com.jetbrains.*`) is also recognized automatically.

## Comparison with Alternatives

| Tool                 | Approach                                      | File types | URLs | Open source | Limitations                                                  |
| -------------------- | --------------------------------------------- | ---------- | ---- | ----------- | ------------------------------------------------------------ |
| **Trampoline**       | Registers as handler, forwards to editor      | Yes        | No   | Yes (MIT)   | macOS 14+ only, one editor for all extensions (v1)           |
| **duti**             | Calls `LSSetDefaultRoleHandlerForContentType` | Yes        | Yes  | Yes         | Triggers a confirmation dialog per extension on modern macOS |
| **SwiftDefaultApps** | System Preferences pane + CLI (`swda`)        | Yes        | Yes  | Yes (MIT)   | Preferences pane deprecated in macOS 13+, same dialog issue  |
| **OpenIn**           | Trampoline pattern for URLs + files           | Yes        | Yes  | No ($10)    | Paid, primarily URL-focused, not developer-file-oriented     |
| **Finicky**          | Trampoline pattern for URLs                   | No         | Yes  | Yes (MIT)   | Browser routing only, does not handle file types             |

Trampoline is purpose-built for the developer file type problem. It manages 85 extensions out of the box, exports custom UTIs for types that macOS does not natively recognize, and provides both a GUI and CLI for managing handler registration. Unlike `duti` and `swda`, it avoids the per-extension dialog problem by acting as the handler itself rather than trying to reassign handlers through the LaunchServices API.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode Command Line Tools (for building from source)

## License

[MIT](LICENSE)
