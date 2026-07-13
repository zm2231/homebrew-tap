require "json"

class Agenthail < Formula
  include Language::Python::Virtualenv

  desc "Connect Claude Code, Codex, and Notion agent sessions"
  homepage "https://github.com/zm2231/agenthail"
  url "https://github.com/zm2231/agenthail/releases/download/v0.1.2/agenthail-v0.1.2-darwin-arm64.tar.gz"
  version "0.1.2"
  sha256 "0f9502e5ce45850baff73657c35f94d61ca58c0415a820c2b3e101fa9518f673"
  license "PolyForm-Noncommercial-1.0.0"

  depends_on arch: :arm64
  depends_on "node"
  depends_on "python@3.13"

  def install
    libexec.install "agenthail"
    libexec.install "sidecar/cookie.mjs", "sidecar/package-lock.json", "sidecar/package.json", "sidecar/sidecar.py"
    libexec.install "skills"

    venv = virtualenv_create(libexec/"venv", formula_opt_bin("python@3.13")/"python3.13")
    venv.pip_install ["certifi==2026.6.17", "cffi==2.1.0", "curl_cffi==0.15.0"]
    system formula_opt_bin("node")/"npm", "ci", "--omit=dev", "--prefix", libexec

    (bin/"agenthail").write_env_script libexec/"agenthail", {
      AGENTHAIL_COOKIE_BRIDGE: libexec/"cookie.mjs",
      AGENTHAIL_PYTHON:        libexec/"venv/bin/python",
      AGENTHAIL_SIDECAR:       libexec/"sidecar.py",
    }
  end

  service do
    run [opt_bin/"agenthail", "daemon-run"]
    keep_alive true
    log_path var/"log/agenthail.log"
    error_log_path var/"log/agenthail.log"
  end

  test do
    version_info = JSON.parse(shell_output("#{bin}/agenthail version --json"))
    assert_equal version.to_s, version_info["version"].delete_prefix("v")
    assert_equal "815b0d268204bfd85bc04330a5922afb15f2770f", version_info["revision"]
    assert_match "agenthail - hail an agent", shell_output("#{bin}/agenthail --help")
  end
end
