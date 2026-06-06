cask "lokalite" do
  version "1.1.2"
  sha256 "2ed4e7dc93c254e3d05d8cdaaf864cb1ae2dfaa81e69466cebe9cdbe68c6e22b"

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
