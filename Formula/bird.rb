class Bird < Formula
  desc "Fast X CLI for tweeting, replying, and reading"
  homepage "https://github.com/zm2231/bird"
  url "https://github.com/zm2231/bird/releases/download/v0.8.0/bird-macos-universal-v0.8.0.tar.gz"
  sha256 "94e5e2858f44ccf718f02cd36add9c3f059889da6e3b45f390ef63269f462e7d"
  license "MIT"

  depends_on :macos

  def install
    bin.install "bird"
  end

  def caveats
    <<~EOS
      bird uses X/Twitter GraphQL with local browser cookies by default.
      This is an undocumented/private API and can break whenever X changes things.
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/bird --version")
  end
end
