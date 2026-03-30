# Trampoline

A macOS menu bar app that makes developer files open in your preferred
code editor -- no confirmation dialogs, no clicking through Finder
preferences for every file type.

## The Problem

You install a code editor. You want `.ts`, `.rs`, `.go`, `.vue`, and
dozens of other developer files to open in it. macOS has no "set default
editor for all code files" option. Your choices:

- **Finder > Get Info > Open With > Change All** -- one file type at a
  time, 85 times
- **`duti` or `swda`** -- triggers a macOS confirmation dialog for each
  extension, 85 times
- **Edit the LaunchServices database directly** -- corrupts it

## The Solution

Install Trampoline. Pick your editor. Done.

Trampoline registers itself as the handler for 85 developer file
extensions. When you double-click a `.rs` file, macOS sends it to
Trampoline, which instantly forwards it to your editor. You never see
Trampoline -- the file opens in your editor as if it were the default
handler.

60 of the 85 extensions are handled silently with zero dialogs. The
remaining 25 (common types like `.json`, `.py`, `.sh` that are already
claimed by Xcode or Terminal) can be claimed with a one-time
confirmation dialog per extension.

## Installation

### Build from Source

Requires Xcode Command Line Tools and macOS 14.0 (Sonoma) or later.

```sh
git clone https://github.com/rmk40/trampoline.git
cd trampoline
make install
```

This compiles the app, copies it to `/Applications`, registers it with
macOS, and creates the `trampoline` CLI at `/usr/local/bin/trampoline`.

To uninstall:

```sh
make uninstall
```

## Quick Start

### GUI

1. Launch Trampoline -- it appears in the menu bar
2. Click the menu bar icon > **Settings...**
3. Pick your editor from the dropdown
4. Optionally click **Claim Unclaimed** to take over the remaining
   system-owned extensions

### CLI

```sh
trampoline editor zed          # Set your editor
trampoline status              # See which extensions are handled
trampoline claim               # Claim unclaimed extensions
```

## Per-Extension Editor Routing

By default, every file opens in your global editor. You can override
specific extensions to use different editors:

```sh
# JVM files in IntelliJ, notebooks in VS Code
trampoline editor .kt,.kts,.scala intellij
trampoline editor .ipynb vscode

# See all overrides
trampoline editor --list

# Clear an override
trampoline editor .kt --clear
```

Or in the GUI: **Extensions tab** > select extensions > **Set Editor...**

## Managed Extensions (85)

| Category       | Extensions                                                                              |
| -------------- | --------------------------------------------------------------------------------------- |
| TypeScript     | `.ts` `.mts` `.cts` `.tsx`                                                              |
| React          | `.jsx`                                                                                  |
| Web frameworks | `.vue` `.svelte` `.astro`                                                               |
| Systems        | `.rs` `.go` `.zig` `.nim`                                                               |
| JVM            | `.kt` `.kts` `.scala` `.sc` `.groovy` `.gvy`                                            |
| .NET           | `.cs` `.fs` `.fsi` `.fsx`                                                               |
| Mobile         | `.dart`                                                                                 |
| Scripting      | `.lua` `.coffee` `.py` `.rb`                                                            |
| Functional     | `.ex` `.exs` `.elm` `.hs` `.lhs` `.ml` `.mli`                                           |
| R              | `.r` `.R`                                                                               |
| Stylesheets    | `.sass` `.scss` `.less` `.styl`                                                         |
| Templates      | `.jade` `.pug` `.ejs` `.hbs` `.handlebars` `.mustache` `.twig` `.jinja` `.jinja2` `.j2` |
| Documents      | `.mdx` `.ipynb`                                                                         |
| Data           | `.json` `.yaml` `.yml` `.xml` `.sql` `.tsv`                                             |
| Config/IaC     | `.tf` `.tfvars` `.hcl` `.toml` `.nix` `.dhall` `.env` `.conf` `.properties`             |
| Schema         | `.graphql` `.gql` `.proto` `.prisma`                                                    |
| Shell          | `.sh` `.bash` `.zsh`                                                                    |
| Build          | `.makefile` `.cmake` `.gradle`                                                          |
| Containers     | `.dockerfile`                                                                           |
| Other          | `.lock` `.gitignore` `.gitattributes` `.editorconfig` `.gemspec` `.patch` `.diff`       |

## Supported Editors

Use the shorthand, bundle ID, or display name when setting your editor.
Any `.app` on your system works -- these are just the ones with
built-in shortcuts.

| Shorthand         | Editor             |
| ----------------- | ------------------ |
| `zed`             | Zed                |
| `vscode`          | Visual Studio Code |
| `vscode-insiders` | VS Code Insiders   |
| `cursor`          | Cursor             |
| `sublime`         | Sublime Text       |
| `nova`            | Nova               |
| `bbedit`          | BBEdit             |
| `textmate`        | TextMate           |
| `webstorm`        | WebStorm           |
| `intellij`        | IntelliJ IDEA      |
| `fleet`           | Fleet              |

All JetBrains IDEs are recognized automatically.

## CLI Reference

```
trampoline editor                           Show current editor
trampoline editor zed                       Set default editor
trampoline editor com.example.MyEditor      Set by bundle ID
trampoline editor .ext                      Show editor for extension
trampoline editor .kt,.kts intellij         Set per-extension override
trampoline editor .kt --clear               Clear override
trampoline editor --list                    Show all overrides
trampoline status                           Show extension status
trampoline status --json                    Machine-readable status
trampoline claim                            Claim unclaimed extensions
trampoline claim --all                      Claim all (may show dialogs)
trampoline install-cli                      Create CLI symlink
trampoline uninstall                        Remove CLI and preferences
```

## Alternatives

| Tool                 | Approach                            | Dialogs?                           | Open source |
| -------------------- | ----------------------------------- | ---------------------------------- | ----------- |
| **Trampoline**       | Registers as handler, forwards      | 0 for 60 extensions, 1 each for 25 | Yes (MIT)   |
| **duti**             | Reassigns handlers via LS API       | 1 per extension                    | Yes         |
| **SwiftDefaultApps** | System Preferences pane             | 1 per extension                    | Yes         |
| **OpenIn**           | Trampoline pattern for URLs + files | Varies                             | No ($10)    |
| **Finicky**          | Trampoline pattern for URLs only    | N/A                                | Yes         |

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode Command Line Tools (for building from source)

## License

[MIT](LICENSE)
