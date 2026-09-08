# Linux: Ubuntu release and kernel

SSOT for distro/kernel. `PROFILE=docker-jobs` + Ubuntu 26.04 / kernel 7.x
without a 6.8 pin path → preflight **BLOCK**.

| Goal | Distro | Kernel | AppArmor |
|---|---|---|---|
| `minimal` | Ubuntu **24.04 LTS** | whatever 24.04 ships | on |
| `docker-jobs` | Ubuntu **24.04 LTS** | **GA 6.8** (`linux-generic`) | **off** (`apparmor=0`) |
| Do not use | Ubuntu **26.04** | 7.0 | — |

Prefer the **Server** ISO (GA 6.8). The 24.04.4 **Desktop** ISO boots **HWE
7.0**. Other 6.x that is not 6.8 (e.g. `6.17.0-*-oem`) is also pinned to GA
6.8 for `docker-jobs`. `linux/pin-ga-kernel.sh` installs `linux-generic`, pins
GRUB, holds HWE metapackages.

Nested bwrap inside Docker needs:

```
# /etc/sysctl.d/99-userns.conf
kernel.unprivileged_userns_clone = 1
kernel.apparmor_restrict_unprivileged_userns = 0
```

Sysctls are not enough while AppArmor is on (`bwrap: Failed to make / slave:
Permission denied`). Do **not** put `"apparmor-profile": "unconfined"` in
`/etc/docker/daemon.json` — Docker Engine 29.7.x refuses to start.

Dedicated runner: `apparmor=0` on the cmdline, mask `apparmor.service` and
`snapd.apparmor.service` (`linux/disable-apparmor.sh`). After reboot: cmdline
has `apparmor=0`, `/sys/kernel/security/apparmor` is absent.

Listener is native systemd (`sudo ./svc.sh install <user>`). Docker Engine
stays on the host for jobs. One `Runner.Listener`. On Debian/Ubuntu:

```
echo '$nrconf{override_rc}{qr(^actions\.runner\..+\.service$)} = 0;' | sudo tee /etc/needrestart/conf.d/actions_runner_services.conf
```
