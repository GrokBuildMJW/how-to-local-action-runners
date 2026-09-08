#!/usr/bin/env bash
# Dedicated CI box only. Nested bwrap in docker-jobs needs apparmor=0 rather
# than fighting docker-default profiles. See KERNEL.md.
set -euo pipefail
if [[ $(id -u) -ne 0 ]]; then
  echo "disable-apparmor.sh must run as root" >&2
  exit 1
fi

install -d /etc/default/grub.d
cat >/etc/default/grub.d/98-disable-apparmor.cfg <<'EOF'
GRUB_CMDLINE_LINUX="${GRUB_CMDLINE_LINUX:+$GRUB_CMDLINE_LINUX }apparmor=0"
EOF

update-grub

systemctl disable --now apparmor.service 2>/dev/null || true
systemctl disable --now snapd.apparmor.service 2>/dev/null || true
systemctl mask apparmor.service 2>/dev/null || true
systemctl mask snapd.apparmor.service 2>/dev/null || true

echo APPARMOR_MASKED=1
grep -n apparmor=0 /boot/grub/grub.cfg | head -5 || true
echo REBOOT_REQUIRED=1
