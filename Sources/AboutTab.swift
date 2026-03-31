import SwiftUI

struct AboutTab: View {

    private static let githubURL = URL(string: "https://github.com/rmk40/trampoline")
    private static let issuesURL = URL(string: "https://github.com/rmk40/trampoline/issues")

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // App icon
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 128, height: 128)

            // Title
            Text("Trampoline")
                .font(.title)

            // Version
            Text("Version \(ExtensionRegistry.version)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Description
            VStack(spacing: 10) {
                Text("Trampoline registers itself as the default handler for developer file extensions, then silently forwards files to your preferred code editor.")

                Text("No more clicking through dozens of dialogs to set your editor as the default for every file type.")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 420)

            // Links
            HStack(spacing: 20) {
                if let url = Self.githubURL {
                    Link("GitHub Repository", destination: url)
                }
                if let url = Self.issuesURL {
                    Link("Report an Issue", destination: url)
                }
            }

            // License & author
            Text("License: MIT")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Created by Rafi Khardalian")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    private var appIcon: NSImage {
        // Prefer the bundled SVG for crisp vector rendering
        if let svgPath = Bundle.main.path(
            forResource: "trampoline_app_icon", ofType: "svg"),
           let svgImage = NSImage(contentsOfFile: svgPath) {
            svgImage.size = NSSize(width: 128, height: 128)
            return svgImage
        }
        // Fallback: app icon from the bundle
        let source = NSApp.applicationIconImage ?? NSImage(
            named: NSImage.applicationIconName) ?? NSImage()
        let icon = source.copy() as? NSImage ?? source
        icon.size = NSSize(width: 128, height: 128)
        return icon
    }
}
