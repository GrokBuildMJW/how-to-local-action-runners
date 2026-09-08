---
id: example-windows-x64-minipc
kind: example
os: windows
arch: [x64]
apply: windows/APPLY.md
dedicated_host_only: true
runner_name: ci-win-1
install_dir: C:\actions-runner
labels:
  - windows
  - x64
match_hardware:
  cpu_family: AMD Ryzen 7 6800H class (8c/16t, x64 mini-PC)
  ram_class_gib: 32
  os: Windows 11
---

# Windows CI — x64 mini-PC

Windows 11 x64. Typical: Ryzen 7 6800H, ~32 GiB. Install under
`C:\actions-runner`.

```powershell
$env:DEDICATED_RUNNER = '1'
.\windows\install.ps1 `
  -GitHubUrl 'https://github.com/<owner>/<repo>' `
  -Token $env:RUNNER_TOKEN `
  -RunnerName 'ci-win-1' `
  -Labels 'windows,x64'
```

```yaml
runs-on: [self-hosted, windows, x64]
```
