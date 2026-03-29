# Trampoline - Design Specification

**Bundle ID:** `com.maelos.trampoline`
**App Name:** Trampoline
**Version:** 1.0 (design)
**Date:** 2026-03-29

## Problem Statement

macOS has no good way to set a single code editor as the default "Open With"
handler for dozens of developer file extensions without either:

1. Triggering a confirmation dialog for each extension (via the
   `LSSetDefaultRoleHandlerForContentType` API or `duti`)
2. Directly manipulating the LaunchServices plist (which corrupts it)

Editors like Zed, VSCode, and Sublime declare `CFBundleDocumentTypes` in their
`Info.plist`, which makes them _candidates_ for file types -- but they don't
claim all developer extensions, and there's no API to silently take over
from another handler.

## Solution

Trampoline is a macOS app that registers itself as the default handler for all
developer file extensions via `CFBundleDocumentTypes` in its `Info.plist`. When
a file is double-clicked, Trampoline receives the open event and immediately
forwards it to the user's configured editor. The user sees the file open in
their editor; Trampoline is invisible.

This is the same pattern used by:

- **Finicky** (4.7k stars) -- registers as default browser, forwards URLs to
  the correct browser based on rules
- **OpenIn** (paid, Mac App Store) -- registers as handler for URLs and file
  types, forwards to the correct app

Neither handles developer file types as a primary use case. Trampoline fills
this gap.

## Key Properties

| Property     | Value                                |
| ------------ | ------------------------------------ |
| Bundle ID    | `com.maelos.trampoline`              |
| App name     | Trampoline                           |
| Language     | Swift (SwiftUI + AppKit)             |
| Min macOS    | 14.0 (Sonoma)                        |
| Distribution | Homebrew cask, GitHub releases       |
| License      | MIT                                  |
| GUI          | SwiftUI settings window              |
| CLI          | Built into app binary                |
| Menu bar     | Optional status item (`LSUIElement`) |
| Dock icon    | Never shown                          |
| App signing  | Developer ID (not Mac App Store)     |

## Document Index

| Document                                 | Contents                                              |
| ---------------------------------------- | ----------------------------------------------------- |
| [01-architecture.md](01-architecture.md) | System architecture, component diagram, tech stack    |
| [02-use-cases.md](02-use-cases.md)       | All use cases with flow references                    |
| [03-flows.md](03-flows.md)               | Detailed flow diagrams for every operation            |
| [04-wireframes.md](04-wireframes.md)     | Screen designs for GUI and CLI                        |
| [05-data-model.md](05-data-model.md)     | Configuration, Info.plist structure, UTI declarations |
| [06-phases.md](06-phases.md)             | Implementation phases and milestones                  |

## Prior Art Analysis

| App              | Pattern                     | File types | URLs | Open source | Our takeaway                                                            |
| ---------------- | --------------------------- | ---------- | ---- | ----------- | ----------------------------------------------------------------------- |
| Finicky          | Trampoline for URLs         | No         | Yes  | Yes (MIT)   | Lifecycle model, dual-mode (stay running / launch-quit), menu bar agent |
| OpenIn           | Trampoline for URLs + files | Yes        | Yes  | No ($10)    | Settings window layout, "Fix It" button for claiming extensions         |
| SwiftDefaultApps | Preferences pane            | Yes        | Yes  | Yes (MIT)   | CLI design (`swda`), "ThisAppDoesNothing" dummy handler pattern         |
| DevFileTypes     | UTI declarations + scripts  | N/A        | No   | Yes         | UTI export/import declarations, extension list, editor detection logic  |

## Non-Goals

- Per-extension routing to different editors (v1 routes everything to one editor)
- URL scheme handling (Finicky does this well already)
- Quick Look integration (orthogonal concern, stays in DevFileTypes)
- File type icon customization
- Mac App Store distribution (requires sandbox, limits handler registration)
