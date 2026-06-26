cask "lokalite-app" do
  version "1.8.1"
  sha256 "f0f240b5316dc7a80dea004410bf1a222a0f27575bfcf14c24e8d5e11d0dfb44"

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
