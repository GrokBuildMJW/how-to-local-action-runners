#!/usr/bin/env bash
# Pin Ubuntu 24.04 to the GA 6.8 kernel. 24.04.4 Desktop ISO ships HWE 7.0;
# nested bwrap in docker-jobs is known-good on 6.8. See KERNEL.md.
set -euo pipefail
if [[ $(id -u) -ne 0 ]]; then
  echo "pin-ga-kernel.sh must run as root" >&2
  exit 1
fi
export DEBIAN_FRONTEND=noninteractive

. /etc/os-release
if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
  echo "pin-ga-kernel.sh is for Ubuntu 24.04 only (have ${ID:-?} ${VERSION_ID:-?})" >&2
  exit 1
fi

apt-get update -y
apt-get install -y linux-generic linux-image-generic linux-headers-generic

K68=$(ls -1 /boot/vmlinuz-6.8.*-generic 2>/dev/null | sed 's|.*/vmlinuz-||' | sort -V | tail -1)
if [[ -z "$K68" ]]; then
  echo "no 6.8 generic vmlinuz after install" >&2
  ls -l /boot/vmlinuz-* >&2 || true
  exit 1
fi

UUID=$(findmnt -no UUID /)
SAVED="gnulinux-advanced-${UUID}>gnulinux-${K68}-advanced-${UUID}"

# Leave installed HWE 7.0 images as emergency fallback; do not pull newer 7.0.
apt-mark hold linux-generic-hwe-24.04 linux-image-generic-hwe-24.04 linux-headers-generic-hwe-24.04 \
  linux-hwe-24.04-tools-common 2>/dev/null || true
apt-mark hold "linux-image-${K68}" "linux-headers-${K68}" linux-generic linux-image-generic linux-headers-generic

install -d /etc/default/grub.d
cat >/etc/default/grub.d/99-pin-ga-68.cfg <<'EOF'
GRUB_DEFAULT=saved
GRUB_SAVEDEFAULT=false
EOF

if grep -q '^GRUB_DEFAULT=' /etc/default/grub; then
  sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT=saved/' /etc/default/grub
else
  echo 'GRUB_DEFAULT=saved' >>/etc/default/grub
fi

update-grub
grub-set-default "$SAVED"
grub-editenv list || true
echo PINNED_SAVED="$SAVED"
echo PINNED_KERNEL="$K68"
echo REBOOT_REQUIRED=1
