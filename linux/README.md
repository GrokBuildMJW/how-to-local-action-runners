# Linux

[`APPLY.md`](APPLY.md), [`KERNEL.md`](KERNEL.md).

| File | Role |
|---|---|
| `preflight.sh` | `KEY=value` + `DECISION=` |
| `install.sh` | Host prep + register + systemd |
| `verify.sh` | One listener |
| `pin-ga-kernel.sh` | Ubuntu 24.04 → GA 6.8 |
| `disable-apparmor.sh` | `apparmor=0`, mask units |

| Variable | Required | Default |
|---|---|---|
| `DEDICATED_RUNNER` | yes | `1` |
| `GITHUB_URL` | install | — |
| `RUNNER_TOKEN` | install | — |
| `RUNNER_NAME` | install | hostname |
| `RUNNER_LABELS` | no | empty |
| `RUNNER_USER` | no | `$SUDO_USER` or `runner` |
| `RUNNER_DIR` | no | `/home/$RUNNER_USER/actions-runner` |
| `PROFILE` | no | `docker-jobs` |
| `FORCE` | no | unset |
