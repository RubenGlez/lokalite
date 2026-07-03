cask "lokalite-app" do
  version "2.3.0"
  sha256 "9069686679033032bbdd17fa0a15d03d7ff5698e8bec10625537c1659d3af9c3"

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
