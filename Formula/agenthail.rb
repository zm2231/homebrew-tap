require "json"

class Agenthail < Formula
  include Language::Python::Virtualenv

  desc "Connect Claude Code, Codex, and Notion agent sessions"
  homepage "https://github.com/zm2231/agenthail"
  url "https://github.com/zm2231/agenthail/releases/download/v0.2.12/agenthail-v0.2.12-darwin-arm64.tar.gz"
  version "0.2.12"
  sha256 "bbe08dcec335bfc2b9abc812a1a3b060800d3169db4f6bb7ac10a4ada4f1a001"
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
      export AGENTHAIL_DAEMON_LOG="#{var}/log/agenthail.log"
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
    service_target = "gui/#{Process.uid}/homebrew.mxcl.agenthail"
    if quiet_system("/bin/launchctl", "print", service_target) &&
       !quiet_system("/bin/launchctl", "kickstart", "-k", service_target)
      opoo "Agenthail could not restart its existing daemon; run brew services restart agenthail"
    end
    if helper.executable?
      packaged_helper = Pathname.new("/Applications/Agenthail.app/Contents/MacOS/Agenthail")
      if packaged_helper.executable? && packaged_helper.realpath != helper.realpath
        system packaged_helper, "service", "disable"
        quiet_system "/usr/bin/pkill", "-u", Process.uid.to_s, "-f", "^#{Regexp.escape(packaged_helper.to_s)}$"
      end
      unless quiet_system helper, "service", "enable"
        opoo "Agenthail could not register its login item; open the app once to retry"
      end
      process_pattern = "/Cellar/agenthail/.*/Agenthail.app/Contents/MacOS/Agenthail"
      quiet_system "/usr/bin/pkill", "-u", Process.uid.to_s, "-f", process_pattern
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
    assert_equal "8e279f7eb07a20399e16ffe91ed4fa6f8a802061", version_info["revision"]
    assert_match "agenthail - hail an agent", shell_output("#{bin}/agenthail --help")
    assert_path_exists libexec/"skills/agenthail-operations/SKILL.md"
    assert_predicate testpath/".hermes/skills/agenthail-operations", :symlink?
  end
end
