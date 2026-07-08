cask "lokalite-app" do
  version "2.5.1"
  sha256 "49cf8e95c74382b4c80191ce2fa76942802e79358207b526ac2127f881fdd169"

  url "https://github.com/RubenGlez/lokalite/releases/download/v#{version}/Lokalite-v#{version}.dmg"
  name "Lokalite"
  desc "Local-first secrets manager for developers — menu bar app"
  homepage "https://github.com/RubenGlez/lokalite"

  depends_on macos: :sonoma

  app "LokaliteApp.app"

  zap trash: [
    "~/Library/Application Support/Lokalite",
    "~/Library/Preferences/com.lokalite.app.plist",
  ]
end
