cask "trampoline" do
  version "1.0"
  sha256 "PLACEHOLDER"

  url "https://github.com/maelos/trampoline/releases/download/v#{version}/Trampoline-#{version}.zip"
  name "Trampoline"
  desc "Developer file handler trampoline for macOS"
  homepage "https://github.com/maelos/trampoline"

  depends_on macos: ">= :sonoma"

  app "Trampoline.app"
  binary "#{appdir}/Trampoline.app/Contents/MacOS/Trampoline", target: "trampoline"

  postflight do
    system_command "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
      args: ["-f", "#{appdir}/Trampoline.app"]
  end

  zap trash: [
    "~/Library/Preferences/com.maelos.trampoline.plist",
    "~/Library/Caches/com.maelos.trampoline",
    "~/Library/Saved Application State/com.maelos.trampoline.savedState",
  ]
end
