import AppKit
import CoreServices
import UniformTypeIdentifiers

// MARK: - Types

enum HandlerRank { case primary, alternate }
enum HandlerStatus: Equatable {
    case claimed
    case other(bundleID: String, displayName: String)
    case unclaimed
}

struct ManagedExtension {
    let ext: String         // e.g., "rs"
    let uti: String?        // e.g., "dev.devfiletypes.rust-source" or nil for dynamic
    let category: String    // e.g., "Systems", "Web frameworks"
    let rank: HandlerRank   // Default vs Alternate in Info.plist
}

// MARK: - Registry

/// Single source of truth for all managed extensions and their Launch Services
/// interactions. All code paths (CLI, GUI, FileForwarder) must use this
/// registry — never hardcode an extension or call LS APIs elsewhere.
enum ExtensionRegistry {

    /// The Trampoline bundle identifier, used to detect claimed extensions.
    static let trampolineBundleID = "com.maelos.trampoline"

    /// App version string, single source of truth.
    static let version = "1.0"

    // MARK: - Complete extension list (85 entries)

    static let all: [ManagedExtension] = {
        var list = [ManagedExtension]()

        // ── Custom UTI (60 extensions, rank = .primary) ──────────────

        let customUTI: [(String, String, String)] = [
            // TypeScript
            ("ts",          "dev.devfiletypes.typescript-source",   "TypeScript"),
            ("mts",         "dev.devfiletypes.typescript-source",   "TypeScript"),
            ("cts",         "dev.devfiletypes.typescript-source",   "TypeScript"),
            // R
            ("r",           "dev.devfiletypes.r-source",            "R"),
            ("R",           "dev.devfiletypes.r-source",            "R"),
            // React
            ("tsx",         "dev.devfiletypes.tsx-source",          "React"),
            ("jsx",         "dev.devfiletypes.jsx-source",          "React"),
            // Web frameworks
            ("vue",         "dev.devfiletypes.vue-source",          "Web frameworks"),
            ("svelte",      "dev.devfiletypes.svelte-source",       "Web frameworks"),
            ("astro",       "dev.devfiletypes.astro-source",        "Web frameworks"),
            // Systems
            ("rs",          "dev.devfiletypes.rust-source",         "Systems"),
            ("go",          "dev.devfiletypes.go-source",           "Systems"),
            ("zig",         "dev.devfiletypes.zig-source",          "Systems"),
            ("nim",         "dev.devfiletypes.nim-source",          "Systems"),
            // JVM
            ("kt",          "dev.devfiletypes.kotlin-source",       "JVM"),
            ("kts",         "dev.devfiletypes.kotlin-source",       "JVM"),
            ("scala",       "dev.devfiletypes.scala-source",        "JVM"),
            ("sc",          "dev.devfiletypes.scala-source",        "JVM"),
            ("groovy",      "dev.devfiletypes.groovy-source",       "JVM"),
            ("gvy",         "dev.devfiletypes.groovy-source",       "JVM"),
            // .NET
            ("cs",          "dev.devfiletypes.csharp-source",       ".NET"),
            ("fs",          "dev.devfiletypes.fsharp-source",       ".NET"),
            ("fsi",         "dev.devfiletypes.fsharp-source",       ".NET"),
            ("fsx",         "dev.devfiletypes.fsharp-source",       ".NET"),
            // Mobile
            ("dart",        "dev.devfiletypes.dart-source",         "Mobile"),
            // Scripting
            ("lua",         "dev.devfiletypes.lua-source",          "Scripting"),
            ("coffee",      "dev.devfiletypes.coffeescript-source",  "Scripting"),
            // Functional
            ("ex",          "dev.devfiletypes.elixir-source",       "Functional"),
            ("exs",         "dev.devfiletypes.elixir-source",       "Functional"),
            ("elm",         "dev.devfiletypes.elm-source",          "Functional"),
            ("hs",          "dev.devfiletypes.haskell-source",      "Functional"),
            ("lhs",         "dev.devfiletypes.haskell-source",      "Functional"),
            ("ml",          "dev.devfiletypes.ocaml-source",        "Functional"),
            ("mli",         "dev.devfiletypes.ocaml-source",        "Functional"),
            // Config/IaC
            ("tf",          "dev.devfiletypes.terraform-source",    "Config/IaC"),
            ("tfvars",      "dev.devfiletypes.terraform-source",    "Config/IaC"),
            ("hcl",         "dev.devfiletypes.hcl-source",          "Config/IaC"),
            ("toml",        "dev.devfiletypes.toml-source",         "Config/IaC"),
            ("nix",         "dev.devfiletypes.nix-source",          "Config/IaC"),
            ("dhall",       "dev.devfiletypes.dhall-source",        "Config/IaC"),
            // Schema
            ("graphql",     "dev.devfiletypes.graphql-source",      "Schema"),
            ("gql",         "dev.devfiletypes.graphql-source",      "Schema"),
            ("proto",       "dev.devfiletypes.protobuf-source",     "Schema"),
            ("prisma",      "dev.devfiletypes.prisma-source",       "Schema"),
            // Stylesheets
            ("sass",        "dev.devfiletypes.sass-source",         "Stylesheets"),
            ("scss",        "dev.devfiletypes.scss-source",         "Stylesheets"),
            ("less",        "dev.devfiletypes.less-source",         "Stylesheets"),
            ("styl",        "dev.devfiletypes.stylus-source",       "Stylesheets"),
            // Templates
            ("jade",        "dev.devfiletypes.jade-source",         "Templates"),
            ("pug",         "dev.devfiletypes.jade-source",         "Templates"),
            ("ejs",         "dev.devfiletypes.ejs-source",          "Templates"),
            ("hbs",         "dev.devfiletypes.handlebars-source",   "Templates"),
            ("handlebars",  "dev.devfiletypes.handlebars-source",   "Templates"),
            ("mustache",    "dev.devfiletypes.mustache-source",     "Templates"),
            ("twig",        "dev.devfiletypes.twig-source",         "Templates"),
            ("jinja",       "dev.devfiletypes.jinja-source",        "Templates"),
            ("jinja2",      "dev.devfiletypes.jinja-source",        "Templates"),
            ("j2",          "dev.devfiletypes.jinja-source",        "Templates"),
            // Documents
            ("mdx",         "dev.devfiletypes.mdx-source",          "Documents"),
            ("ipynb",       "dev.devfiletypes.jupyter-notebook",    "Documents"),
        ]

        for (ext, uti, category) in customUTI {
            list.append(ManagedExtension(
                ext: ext, uti: uti, category: category, rank: .primary))
        }

        // ── System UTI (7 extensions, rank = .alternate) ─────────────

        let systemUTI: [(String, String, String)] = [
            ("json",  "public.json",           "Data"),
            ("yaml",  "public.yaml",           "Data"),
            ("yml",   "public.yaml",           "Data"),
            ("xml",   "public.xml",            "Data"),
            ("py",    "public.python-script",  "Scripting"),
            ("rb",    "public.ruby-script",    "Scripting"),
            ("sh",    "public.shell-script",   "Shell"),
        ]

        for (ext, uti, category) in systemUTI {
            list.append(ManagedExtension(
                ext: ext, uti: uti, category: category, rank: .alternate))
        }

        // ── Dynamic UTI (18 extensions, rank = .alternate, uti = nil) ─

        let dynamicUTI: [(String, String)] = [
            ("bash",           "Shell"),
            ("zsh",            "Shell"),
            ("sql",            "Data"),
            ("env",            "Config"),
            ("conf",           "Config"),
            ("tsv",            "Data"),
            ("lock",           "Package managers"),
            ("gitignore",      "Git"),
            ("gitattributes",  "Git"),
            ("editorconfig",   "Editor config"),
            ("dockerfile",     "Containers"),
            ("makefile",       "Build"),
            ("gemspec",        "Ruby"),
            ("cmake",          "Build"),
            ("gradle",         "Build"),
            ("properties",     "Config"),
            ("patch",          "Version control"),
            ("diff",           "Version control"),
        ]

        for (ext, category) in dynamicUTI {
            list.append(ManagedExtension(
                ext: ext, uti: nil, category: category, rank: .alternate))
        }

        return list
    }()

    // MARK: - UTI resolution

    /// Resolve the UTI for an extension. Uses the stored UTI if available,
    /// otherwise falls back to dynamic resolution via UniformTypeIdentifiers.
    /// Ported from DevFileTypes `set-handler.swift` resolveUTType().
    private static func resolveUTI(for ext: String) -> String? {
        if let managed = all.first(where: { $0.ext == ext }), let uti = managed.uti {
            return uti
        }
        return UTType(filenameExtension: ext)?.identifier
    }

    // MARK: - Query single handler

    /// Resolves the current default handler for an extension.
    /// This is the ONLY place in the codebase that calls
    /// LSCopyDefaultRoleHandlerForContentType.
    static func queryHandler(
        for ext: String
    ) -> (bundleID: String, displayName: String)? {
        guard let uti = resolveUTI(for: ext) else { return nil }

        guard let handlerRef = LSCopyDefaultRoleHandlerForContentType(
            uti as CFString, .all
        ) else { return nil }

        let bundleID = handlerRef.takeRetainedValue() as String

        let displayName: String
        if let appURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: bundleID
        ) {
            displayName = appURL.deletingPathExtension().lastPathComponent
        } else {
            displayName = bundleID
        }

        return (bundleID, displayName)
    }

    // MARK: - Query all statuses

    /// Returns the handler status for every managed extension.
    static func queryAllStatuses() -> [(ext: String, status: HandlerStatus)] {
        all.map { managed in
            guard let handler = queryHandler(for: managed.ext) else {
                return (managed.ext, .unclaimed)
            }

            if handler.bundleID.lowercased() == trampolineBundleID.lowercased() {
                return (managed.ext, .claimed)
            } else {
                return (managed.ext, .other(
                    bundleID: handler.bundleID,
                    displayName: handler.displayName))
            }
        }
    }

    // MARK: - Claim extensions

    /// Claims the given extensions by setting Trampoline as the default handler.
    /// This is the ONLY place in the codebase that calls
    /// LSSetDefaultRoleHandlerForContentType.
    @discardableResult
    static func claim(
        extensions exts: [String]
    ) -> [(ext: String, success: Bool)] {
        exts.map { ext in
            guard let uti = resolveUTI(for: ext) else {
                return (ext, false)
            }

            let status = LSSetDefaultRoleHandlerForContentType(
                uti as CFString, .all, trampolineBundleID as CFString)

            return (ext, status == noErr)
        }
    }
}
