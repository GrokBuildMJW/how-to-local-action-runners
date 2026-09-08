---
id: example-macos-arm64-mini
kind: example
os: macos
arch: [arm64]
apply: macos/APPLY.md
dedicated_host_only: true
runner_name: ci-mac-1
labels:
  - macos
  - arm64
match_hardware:
  class: Mac mini, Apple silicon
  cpu: Apple M4 class
  ram_class_gib: 16
---

# macOS CI — Mac mini (Apple silicon)

The one-shot picks `osx-arm64` or `osx-x64` from `uname -m`.

```bash
export DEDICATED_RUNNER=1
export GITHUB_URL='https://github.com/<owner>/<repo>'
export RUNNER_TOKEN='...'
export RUNNER_NAME='ci-mac-1'
export RUNNER_LABELS='macos,arm64'
sudo -E ./macos/install.sh
```

```yaml
runs-on: [self-hosted, macos, arm64]
```
