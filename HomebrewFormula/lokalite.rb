class Lokalite < Formula
  desc "Local-first secrets manager for developers — vault, CLI, and MCP server"
  homepage "https://github.com/RubenGlez/lokalite"
  url "https://github.com/RubenGlez/lokalite/archive/refs/tags/v1.1.2.tar.gz"
  sha256 "a66aa371ec63ca28d62702241c4780dc3904dd9e1d8e3ec2593c71ece9465cbe"
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
