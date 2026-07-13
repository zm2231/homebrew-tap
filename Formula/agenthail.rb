class Agenthail < Formula
  include Language::Python::Virtualenv

  desc "Connect Claude Code, Codex, and Notion agent sessions"
  homepage "https://github.com/zm2231/agenthail"
  url "https://github.com/zm2231/agenthail/releases/download/v0.1.1/agenthail-v0.1.1-darwin-arm64.tar.gz"
  version "0.1.1"
  sha256 "bf921375368bb00f3d4b72f0170bd587b63ac89c9db2d8b5a1845325cf18462a"
  license "PolyForm-Noncommercial-1.0.0"

  depends_on arch: :arm64
  depends_on "node"
  depends_on "python@3.13"

  def install
    libexec.install "agenthail"
    libexec.install "sidecar/cookie.mjs", "sidecar/package-lock.json", "sidecar/package.json", "sidecar/sidecar.py"
    libexec.install "skills"

    venv = virtualenv_create(libexec/"venv", formula_opt_bin("python@3.13")/"python3.13")
    venv.pip_install "curl_cffi==0.15.0"
    system formula_opt_bin("node")/"npm", "ci", "--omit=dev", "--prefix", libexec

    bin.write_env_script libexec/"agenthail", {
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
    version_info = json.loads(shell_output("#{bin}/agenthail version --json"))
    assert_equal version.to_s, version_info["version"].delete_prefix("v")
    assert_equal "6f298054f44d416650d879b9e48058b6990efefb", version_info["revision"]
    assert_match "agenthail - hail an agent", shell_output("#{bin}/agenthail --help")
  end
end
