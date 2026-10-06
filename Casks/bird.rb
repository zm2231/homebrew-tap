cask "bird" do
  version "0.8.0"
  sha256 "94e5e2858f44ccf718f02cd36add9c3f059889da6e3b45f390ef63269f462e7d"

  url "https://github.com/zm2231/bird/releases/download/v#{version}/bird-macos-universal-v#{version}.tar.gz"
  name "bird"
  desc "Fast X CLI for tweeting, replying, and reading"
  homepage "https://github.com/zm2231/bird"

  binary "bird"

  caveats <<~EOS
    bird uses X/Twitter GraphQL with local browser cookies by default.
    This is an undocumented/private API and can break whenever X changes things.
  EOS
end
