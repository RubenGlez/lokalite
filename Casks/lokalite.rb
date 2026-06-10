cask "lokalite" do
  version "1.4.1"
  sha256 "3b761f3ec922d2947bb471a5bc345eb60a7a1386b52ed61270f95a6cb353ef5e"

  url "https://github.com/RubenGlez/lokalite/releases/download/v#{version}/Lokalite-v#{version}.dmg"
  name "Lokalite"
  desc "Local-first secrets manager for developers — menu bar app"
  homepage "https://github.com/RubenGlez/lokalite"

  app "LokaliteApp.app"

  zap trash: [
    "~/Library/Application Support/Lokalite",
    "~/Library/Preferences/com.lokalite.app.plist",
  ]
end
