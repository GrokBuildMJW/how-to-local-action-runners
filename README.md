# How-to local action runners

One-shot installers and agent-readable markdown for **dedicated** GitHub
Actions self-hosted runners on Linux, macOS, and Windows.

Agents start at [`AGENTS.md`](AGENTS.md).

| OS | Decision | One-shot | Kernel |
|---|---|---|---|
| Linux | [`linux/APPLY.md`](linux/APPLY.md) | [`linux/install.sh`](linux/install.sh) | [`linux/KERNEL.md`](linux/KERNEL.md) |
| macOS | [`macos/APPLY.md`](macos/APPLY.md) | [`macos/install.sh`](macos/install.sh) | — |
| Windows | [`windows/APPLY.md`](windows/APPLY.md) | [`windows/install.ps1`](windows/install.ps1) | — |

Hardware classes: [`examples/`](examples/README.md).

## Install

Registration token: GitHub → repo or org → Settings → Actions → Runners →
New runner. ~60 minutes. Do not write it to disk.

```bash
export DEDICATED_RUNNER=1
export GITHUB_URL='https://github.com/<owner>/<repo>'
export RUNNER_TOKEN='...'
export RUNNER_NAME='ci-linux-1'
export RUNNER_LABELS='linux,x64'
sudo -E ./linux/install.sh          # Ubuntu 24.04
sudo -E ./macos/install.sh          # macOS
```

```powershell
$env:DEDICATED_RUNNER = '1'
.\windows\install.ps1 -GitHubUrl $env:GITHUB_URL -Token $env:RUNNER_TOKEN -RunnerName $env:RUNNER_NAME -Labels $env:RUNNER_LABELS
```

```yaml
runs-on: [self-hosted, linux, x64]
```

Jobs run as the runner user (Linux/macOS) or NETWORK SERVICE (Windows). Do not
attach a self-hosted runner to a public repo that takes fork pull requests.

Pins: [`pins.env`](pins.env) (runner **2.337.0**).
