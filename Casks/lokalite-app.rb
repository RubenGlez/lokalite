cask "lokalite-app" do
  version "2.9.0"
  sha256 "38b2e9881ac80c5e89f53f28d5eef34b0c873d68020e0898d9ab1cc8aa07b0a5"

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
