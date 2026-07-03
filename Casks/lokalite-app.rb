cask "lokalite-app" do
  version "2.4.0"
  sha256 "238f22a543f6c932c502eea41ce370daa26a1cddd00863446782d7e23fdce6b9"

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
