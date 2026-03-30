import SwiftUI

struct AboutTab: View {

    private static let githubURL = URL(string: "https://github.com/maelos/trampoline")
    private static let issuesURL = URL(string: "https://github.com/maelos/trampoline/issues")

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            // App icon
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 64, height: 64)

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

            // License
            Text("License: MIT")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
    }

    // MARK: - Helpers

    private var appIcon: NSImage {
        let source = NSApp.applicationIconImage ?? NSImage(
            named: NSImage.applicationIconName) ?? NSImage()
        let icon = source.copy() as? NSImage ?? source
        icon.size = NSSize(width: 64, height: 64)
        return icon
    }
}
