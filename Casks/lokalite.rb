cask "lokalite" do
  version "1.4.3"
  sha256 "7786d7a83fd0034370a8b62b6ee12b59b5aca46674614476d1766a19bc5aef7f"

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
