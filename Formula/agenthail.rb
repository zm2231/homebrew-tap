require "json"

class Agenthail < Formula
  include Language::Python::Virtualenv

  desc "Connect Claude Code, Codex, and Notion agent sessions"
  homepage "https://github.com/zm2231/agenthail"
  url "https://github.com/zm2231/agenthail/releases/download/v0.1.4/agenthail-v0.1.4-darwin-arm64.tar.gz"
  version "0.1.4"
  sha256 "e01d97ffe3c6ff777a81b44fad9f534fbf5bc4a2fca8bf973384b02384a19463"
  license "PolyForm-Noncommercial-1.0.0"

  depends_on arch: :arm64
  depends_on macos: :ventura
  depends_on "node"
  depends_on "python@3.13"

  def install
    libexec.install "agenthail"
    libexec.install "Agenthail.app" if File.directory?("Agenthail.app")
    libexec.install "sidecar/cookie.mjs", "sidecar/package-lock.json", "sidecar/package.json", "sidecar/sidecar.py"
    libexec.install "skills"

    venv = virtualenv_create(libexec/"venv", formula_opt_bin("python@3.13")/"python3.13")
    venv.pip_install ["certifi==2026.6.17", "cffi==2.1.0", "curl_cffi==0.15.0"]
    system formula_opt_bin("node")/"npm", "ci", "--omit=dev", "--prefix", libexec

    environment = {
      AGENTHAIL_COOKIE_BRIDGE: libexec/"cookie.mjs",
      AGENTHAIL_PYTHON:        libexec/"venv/bin/python",
      AGENTHAIL_SIDECAR:       libexec/"sidecar.py",
    }
    if (libexec/"Agenthail.app/Contents/MacOS/Agenthail").executable?
      environment[:AGENTHAIL_MAC_APP] = libexec/"Agenthail.app/Contents/MacOS/Agenthail"
    end
    (bin/"agenthail").write_env_script libexec/"agenthail", environment
  end

  def post_install
    skill = opt_libexec/"skills/agenthail-operations"
    if (skill/"SKILL.md").exist?
      [Pathname(Dir.home)/".claude", Pathname(Dir.home)/".codex", Pathname(Dir.home)/".hermes"].each do |runtime|
        next unless runtime.directory?

        link = runtime/"skills/agenthail-operations"
        if link.exist? && !link.symlink?
          opoo "#{link} already exists and was left unchanged"
          next
        end
        (runtime/"skills").mkpath
        ln_sf skill, link
      end
    end

    app = libexec/"Agenthail.app"
    helper = app/"Contents/MacOS/Agenthail"
    if helper.executable?
      unless quiet_system helper, "service", "enable"
        opoo "Agenthail could not register its login item; open the app once to retry"
      end
      system "/usr/bin/open", "-g", "-j", app
    end
  end

  def caveats
    <<~EOS
      Claude Code needs Remote Control for sessions AgentHail can reach.
      In Claude Code, run /config and enable Remote Control for all sessions.

      Launch writable Codex Desktop sessions through AgentHail:
        agenthail launch codex

      Verify every connected surface:
        agenthail doctor
    EOS
  end

  service do
    run [opt_bin/"agenthail", "daemon-run"]
    environment_variables AGENTHAIL_DAEMON_SUPERVISOR: "homebrew", PATH: std_service_path_env
    keep_alive true
    log_path var/"log/agenthail.log"
    error_log_path var/"log/agenthail.log"
  end

  test do
    version_info = JSON.parse(shell_output("#{bin}/agenthail version --json"))
    assert_equal version.to_s, version_info["version"].delete_prefix("v")
    assert_equal "2c7c57a52715399968111889544c803c0b1bb9cc", version_info["revision"]
    assert_match "agenthail - hail an agent", shell_output("#{bin}/agenthail --help")
    assert_path_exists libexec/"skills/agenthail-operations/SKILL.md"
  end
end
