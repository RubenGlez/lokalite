class Lokalite < Formula
  desc "Local-first secrets manager for developers — vault, CLI, and MCP server"
  homepage "https://github.com/RubenGlez/lokalite"
  url "https://github.com/RubenGlez/lokalite/archive/refs/tags/v2.2.1.tar.gz"
  sha256 "2a5c6a5dfe18ee9dfcd75d49dbd394a558a12a0d114efc5fac9d71b1021f7381"
  license "MIT"
  head "https://github.com/RubenGlez/lokalite.git", branch: "main"

  depends_on xcode: ["15.0", :build]
  depends_on :macos => :sonoma

  def install
    system "swift", "build", "--configuration", "release", "--product", "lokalite", "--disable-sandbox"
    bin.install ".build/release/lokalite"
  end

  test do
    assert_match "lokalite", shell_output("#{bin}/lokalite --help")
  end
end
