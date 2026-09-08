---
id: windows-self-hosted-runner
os: windows
arch: [x64, arm64]
contract_version: 1
dedicated_host_only: true
apply_when:
  - os is Windows 10/11 or Windows Server 2016+
  - human wants a persistent GitHub Actions self-hosted runner on this host
  - DEDICATED_RUNNER=1
  - preflight printed DECISION=APPLY
do_not_apply_when:
  - daily-driver workstation and DEDICATED_RUNNER is unset
  - a healthy listener already runs from InstallDir
block_when:
  - not Windows
  - a Runner.Listener is already running from a different directory
  - not elevated (Administrator)
requires:
  env:
    - GITHUB_URL (or -GitHubUrl)
    - RUNNER_TOKEN (or -Token)
    - RUNNER_NAME (or -RunnerName)
    - DEDICATED_RUNNER
  privileges: administrator
  network: github.com
idempotent: true
destructive: false
reboot: never
scripts:
  preflight: windows/preflight.ps1
  install: windows/install.ps1
  verify: windows/verify.ps1
token_policy: never persist; expires ~60 minutes
---

# Windows runner

Install under `C:\actions-runner` (NETWORK SERVICE).
Example: [`examples/windows-x64-minipc.md`](../examples/windows-x64-minipc.md).

```powershell
$env:DEDICATED_RUNNER = '1'
.\windows\preflight.ps1
```

Obey `DECISION=`.

```powershell
$env:DEDICATED_RUNNER = '1'
.\windows\install.ps1 `
  -GitHubUrl 'https://github.com/<owner>/<repo>' `
  -Token $env:RUNNER_TOKEN `
  -RunnerName 'ci-win-1' `
  -Labels 'windows,x64'
```

The one-shot: LocalMachine RemoteSigned, long paths, no AC sleep, MinGit in
`externals\git` on Machine PATH, `config.cmd --runasservice`, `svc.cmd` as
NETWORK SERVICE, `sc.exe failure` restart.

Do not also run `run.cmd` from a scheduled task (two listeners →
`TaskAgentSessionConflict`).

```powershell
.\windows\verify.ps1
```

```yaml
runs-on: [self-hosted, Windows, X64]
```

Do not: install under `C:\Users\...`; user-scope ExecutionPolicy.
