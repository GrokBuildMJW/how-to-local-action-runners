---
id: macos-self-hosted-runner
os: macos
arch: [x64, arm64]
contract_version: 1
dedicated_host_only: true
apply_when:
  - os is macOS 11 or later
  - human wants a persistent GitHub Actions self-hosted runner on this Mac
  - DEDICATED_RUNNER=1
  - preflight printed DECISION=APPLY
do_not_apply_when:
  - daily-driver laptop and DEDICATED_RUNNER is unset
  - a healthy listener already runs from RUNNER_DIR
block_when:
  - not Darwin
  - a Runner.Listener is already running from a different directory
requires:
  env:
    - GITHUB_URL
    - RUNNER_TOKEN
    - RUNNER_NAME
    - DEDICATED_RUNNER
  privileges: root
  network: github.com
idempotent: true
destructive: false
reboot: never
scripts:
  preflight: macos/preflight.sh
  install: macos/install.sh
  verify: macos/verify.sh
token_policy: never persist; expires ~60 minutes
---

# macOS runner

Example: [`examples/macos-arm64-mini.md`](../examples/macos-arm64-mini.md).

```bash
export DEDICATED_RUNNER=1
sudo -E ./macos/preflight.sh
```

Obey `DECISION=`.

```bash
export DEDICATED_RUNNER=1
export GITHUB_URL='https://github.com/<owner>/<repo>'
export RUNNER_TOKEN='...'
export RUNNER_NAME='ci-mac-1'
export RUNNER_LABELS='macos,arm64'
sudo -E ./macos/install.sh
```

The one-shot: arch tarball, SHA-256, Xcode CLT (preflight **BLOCKs** if
missing), `pmset` no sleep, `config.sh --unattended`, LaunchDaemon via
`sudo ./svc.sh install`.

```bash
sudo -E ./macos/verify.sh
```

```yaml
runs-on: [self-hosted, macOS, ARM64]
```

Do not: two listeners; user LaunchAgent; let the Mac sleep.
