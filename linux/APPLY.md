---
id: linux-self-hosted-runner
os: linux
arch: [x64, arm64]
contract_version: 1
dedicated_host_only: true
apply_when:
  - os is Linux
  - human wants a persistent GitHub Actions self-hosted runner on this host
  - DEDICATED_RUNNER=1
  - preflight printed DECISION=APPLY
do_not_apply_when:
  - host is a daily-driver workstation and DEDICATED_RUNNER is unset
  - a healthy listener already runs from RUNNER_DIR
block_when:
  - PROFILE=docker-jobs and Ubuntu 26.04 (or kernel 7.x with no GA 6.8 pin path)
  - a Runner.Listener is already running from a different directory
  - not Linux
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
reboot: maybe
profile_default: docker-jobs
scripts:
  preflight: linux/preflight.sh
  install: linux/install.sh
  verify: linux/verify.sh
token_policy: never persist; expires ~60 minutes
kernel_doc: linux/KERNEL.md
---

# Linux runner

Read [`KERNEL.md`](KERNEL.md) before install.
Example: [`examples/linux-x64-minipc.md`](../examples/linux-x64-minipc.md).

```bash
export DEDICATED_RUNNER=1
export PROFILE=docker-jobs    # or minimal
sudo -E ./linux/preflight.sh
```

Obey `DECISION=`. [`schema/apply.md`](../schema/apply.md).

| `PROFILE` | Host | Use when |
|---|---|---|
| `docker-jobs` (default) | Docker, userns sysctls, GA 6.8, AppArmor off | Docker / nested bwrap jobs |
| `minimal` | Listener + systemd | No container jobs |

```bash
export DEDICATED_RUNNER=1
export GITHUB_URL='https://github.com/<owner>/<repo>'
export RUNNER_TOKEN='...'
export RUNNER_NAME='ci-linux-1'
export RUNNER_LABELS='linux,x64'
sudo -E ./linux/install.sh
```

`REBOOT_REQUIRED=1` → reboot, same command again. Then `sudo -E ./linux/verify.sh`.

```yaml
runs-on: [self-hosted, linux, x64]
```

Do not: Ubuntu 26.04 for `docker-jobs`; `"apparmor-profile"` in
`/etc/docker/daemon.json`; listener in a container; two listeners.
