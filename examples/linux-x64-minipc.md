---
id: example-linux-x64-minipc
kind: example
os: linux
arch: [x64]
apply: linux/APPLY.md
kernel_doc: linux/KERNEL.md
profile: docker-jobs
dedicated_host_only: true
runner_name: ci-linux-1
labels:
  - linux
  - x64
match_hardware:
  cpu_family: AMD Ryzen 7 6800H class (8c/16t, x64 mini-PC)
  ram_class_gib: 32
---

# Linux CI — x64 mini-PC

Ubuntu **24.04**, `PROFILE=docker-jobs`. Typical: Ryzen 7 6800H, ~32 GiB.

```bash
export DEDICATED_RUNNER=1
export PROFILE=docker-jobs
export GITHUB_URL='https://github.com/<owner>/<repo>'
export RUNNER_TOKEN='...'
export RUNNER_NAME='ci-linux-1'
export RUNNER_LABELS='linux,x64'
sudo -E ./linux/install.sh
```

```yaml
runs-on: [self-hosted, linux, x64]
```
