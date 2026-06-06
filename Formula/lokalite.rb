class Lokalite < Formula
  desc "Local-first secrets manager for developers — vault, CLI, and MCP server"
  homepage "https://github.com/RubenGlez/lokalite"
  url "https://github.com/RubenGlez/lokalite/archive/refs/tags/v1.2.3.tar.gz"
  sha256 "a55cfa9be8b58a618518af3c8676d5be284ad6ef8af0e1da2c60a094b31381ab"
  license "MIT"
  head "https://github.com/RubenGlez/lokalite.git", branch: "main"

  depends_on xcode: ["15.0", :build]
  depends_on :macos => :sonoma

  def install
    system "swift", "build", "--configuration", "release", "--product", "lokalite"
    bin.install ".build/release/lokalite"
  end

  test do
    assert_match "lokalite", shell_output("#{bin}/lokalite --help")
  end
end
