require "json"

class Agenthail < Formula
  include Language::Python::Virtualenv

  desc "Connect Claude Code, Codex, and Notion agent sessions"
  homepage "https://github.com/zm2231/agenthail"
  url "https://github.com/zm2231/agenthail/releases/download/v0.2.3/agenthail-v0.2.3-darwin-arm64.tar.gz"
  version "0.2.3"
  sha256 "abc1bb872cf7110e454645021e366a31abe83cfd446727e2f21b4e99a4f27e14"
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

    (bin/"agenthail").write <<~BASH
      #!/bin/bash
      export AGENTHAIL_COOKIE_BRIDGE="#{libexec}/cookie.mjs"
      export AGENTHAIL_MAC_APP="#{libexec}/Agenthail.app/Contents/MacOS/Agenthail"
      export AGENTHAIL_PYTHON="#{libexec}/venv/bin/python"
      export AGENTHAIL_SIDECAR="#{libexec}/sidecar.py"
      skill="#{opt_libexec}/skills/agenthail-operations"
      if [ -f "$skill/SKILL.md" ]; then
        for runtime in "$HOME/.claude" "$HOME/.codex" "$HOME/.hermes"; do
          [ -d "$runtime" ] || continue
          link="$runtime/skills/agenthail-operations"
          mkdir -p "$runtime/skills"
          if [ -L "$link" ]; then
            ln -sfn "$skill" "$link"
          elif [ ! -e "$link" ]; then
            ln -s "$skill" "$link"
          fi
        done
      fi
      exec "#{libexec}/agenthail" "$@"
    BASH
  end

  def post_install
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
    ENV["HOME"] = testpath
    (testpath/".hermes").mkpath
    version_info = JSON.parse(shell_output("#{bin}/agenthail version --json"))
    assert_equal version.to_s, version_info["version"].delete_prefix("v")
    assert_equal "70f5c40ca1551eb4aa12d0df072a59c23e4b7593", version_info["revision"]
    assert_match "agenthail - hail an agent", shell_output("#{bin}/agenthail --help")
    assert_path_exists libexec/"skills/agenthail-operations/SKILL.md"
    assert_predicate testpath/".hermes/skills/agenthail-operations", :symlink?
  end
end
