cask "lokalite" do
  version "1.7.1"
  sha256 "3b71fc47095119a6adbab5ffc33195d0ebd8b21a85d00284a542517b4b8b33c3"

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
