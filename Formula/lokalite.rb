class Lokalite < Formula
  desc "Local-first secrets manager for developers — vault, CLI, and MCP server"
  homepage "https://github.com/RubenGlez/lokalite"
  url "https://github.com/RubenGlez/lokalite/archive/refs/tags/v2.5.1.tar.gz"
  sha256 "26d6f1de1a3af785e6c8093f8ea36d28f3f4f82f46f56ce43b7e8cfc1a4aab51"
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
