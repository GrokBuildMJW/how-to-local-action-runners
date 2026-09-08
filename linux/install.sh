#!/usr/bin/env bash
# One-shot Linux self-hosted runner. Idempotent. See APPLY.md and KERNEL.md.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../shared/lib.sh
source "$ROOT/shared/lib.sh"

need_root
load_pins "$ROOT/pins.env"

PROFILE=${PROFILE:-docker-jobs}
RUNNER_USER=${RUNNER_USER:-${SUDO_USER:-runner}}
RUNNER_DIR=${RUNNER_DIR:-/home/${RUNNER_USER}/actions-runner}
RUNNER_NAME=${RUNNER_NAME:-$(hostname -s)}
RUNNER_LABELS=${RUNNER_LABELS:-}

[[ "${DEDICATED_RUNNER:-}" == "1" ]] || die "set DEDICATED_RUNNER=1 and run with sudo -E"

echo "=== preflight ==="
set +e
pre_out=$(DEDICATED_RUNNER=1 PROFILE="$PROFILE" RUNNER_USER="$RUNNER_USER" RUNNER_DIR="$RUNNER_DIR" FORCE="${FORCE:-}" \
  bash "$ROOT/linux/preflight.sh")
pre_rc=$?
set -e
printf '%s\n' "$pre_out"
decision=$(printf '%s\n' "$pre_out" | awk -F= '/^DECISION=/{print $2; exit}' | awk '{print $1}')
case "$pre_rc" in
  0) ;;
  2) exit 2 ;;
  *) exit "$pre_rc" ;;
esac
if [[ "$decision" == "SKIP" && "${FORCE:-}" != "1" ]]; then
  echo "preflight SKIP; nothing to do"
  bash "$ROOT/linux/verify.sh" || true
  exit 0
fi
if [[ "$decision" == "BLOCK" ]]; then
  exit 2
fi

require_env GITHUB_URL RUNNER_TOKEN

if ! id -u "$RUNNER_USER" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$RUNNER_USER"
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y ca-certificates curl tar jq

reboot_needed=0

if [[ "$PROFILE" == "docker-jobs" ]]; then
  echo "=== docker-jobs host prep ==="
  install -d -m 0755 /etc/sysctl.d
  cat >/etc/sysctl.d/99-userns.conf <<'EOF'
kernel.unprivileged_userns_clone = 1
kernel.apparmor_restrict_unprivileged_userns = 0
EOF
  sysctl --system >/dev/null 2>&1 || sysctl -p /etc/sysctl.d/99-userns.conf

  if [[ -f /etc/docker/daemon.json ]] && grep -q apparmor-profile /etc/docker/daemon.json; then
    echo "removing /etc/docker/daemon.json (apparmor-profile is rejected by Docker 29)"
    rm -f /etc/docker/daemon.json
  fi

  if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
  fi
  usermod -aG docker "$RUNNER_USER"
  systemctl enable --now docker

  k=$(uname -r)
  . /etc/os-release
  if [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "24.04" && "$k" != 6.8.* ]]; then
    bash "$ROOT/linux/pin-ga-kernel.sh"
    reboot_needed=1
  fi
  if [[ -d /sys/kernel/security/apparmor ]] || ! grep -qw apparmor=0 /proc/cmdline 2>/dev/null; then
    bash "$ROOT/linux/disable-apparmor.sh"
    reboot_needed=1
  fi

  if [[ -d /etc/needrestart/conf.d ]]; then
    echo '$nrconf{override_rc}{qr(^actions\.runner\..+\.service$)} = 0;' \
      >/etc/needrestart/conf.d/actions_runner_services.conf
  fi
fi

if [[ "$reboot_needed" -eq 1 ]]; then
  echo "REBOOT_REQUIRED=1"
  echo "NEXT=reboot, then re-run: sudo -E $ROOT/linux/install.sh"
  echo "Do not write RUNNER_TOKEN to disk. Mint a new one if it expires (~60 min)."
  exit 10
fi

echo "=== runner package ==="
arch=$(uname -m)
case "$arch" in
  x86_64) pkg=linux-x64; sum=$RUNNER_SHA256_LINUX_X64 ;;
  aarch64|arm64) pkg=linux-arm64; sum=$RUNNER_SHA256_LINUX_ARM64 ;;
  armv7l|armv6l) pkg=linux-arm; sum=$RUNNER_SHA256_LINUX_ARM ;;
  *) die "unsupported arch $arch" ;;
esac
tarball="actions-runner-${pkg}-${RUNNER_VERSION}.tar.gz"
url="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${tarball}"

install -d -o "$RUNNER_USER" -g "$RUNNER_USER" "$RUNNER_DIR"
if [[ ! -x "$RUNNER_DIR/config.sh" ]]; then
  tmp=$(mktemp)
  curl -fsSL -o "$tmp" "$url"
  assert_sha256 "$tmp" "$sum"
  tar -xzf "$tmp" -C "$RUNNER_DIR"
  rm -f "$tmp"
  chown -R "$RUNNER_USER:$RUNNER_USER" "$RUNNER_DIR"
fi

if [[ ! -f "$RUNNER_DIR/.runner" ]]; then
  echo "=== config.sh ==="
  cfg=(--url "$GITHUB_URL" --token "$RUNNER_TOKEN" --name "$RUNNER_NAME" --work _work --unattended)
  if [[ -n "$RUNNER_LABELS" ]]; then
    cfg+=(--labels "$RUNNER_LABELS")
  fi
  if [[ "${FORCE:-}" == "1" ]]; then
    cfg+=(--replace)
  fi
  cd "$RUNNER_DIR"
  runuser -u "$RUNNER_USER" -- ./config.sh "${cfg[@]}"
else
  echo "already configured; skip config.sh"
fi

echo "=== systemd service ==="
# Stop any interactive listener before svc install.
if pgrep -f "$RUNNER_DIR/bin/Runner.Listener" >/dev/null 2>&1; then
  if [[ ! -f "$RUNNER_DIR/.service" ]]; then
    die "a listener is running but no systemd unit yet; stop it first"
  fi
fi
cd "$RUNNER_DIR"
if [[ ! -f "$RUNNER_DIR/.service" ]]; then
  ./svc.sh install "$RUNNER_USER"
fi
./svc.sh start || true

echo "=== verify ==="
PROFILE="$PROFILE" RUNNER_USER="$RUNNER_USER" RUNNER_DIR="$RUNNER_DIR" bash "$ROOT/linux/verify.sh"
echo INSTALL_OK
