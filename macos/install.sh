#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../shared/lib.sh
source "$ROOT/shared/lib.sh"

need_root
load_pins "$ROOT/pins.env"

RUNNER_USER=${RUNNER_USER:-${SUDO_USER:-}}
[[ -n "$RUNNER_USER" ]] || die "set RUNNER_USER (or run with sudo -E from that user)"
RUNNER_DIR=${RUNNER_DIR:-/Users/${RUNNER_USER}/actions-runner}
RUNNER_NAME=${RUNNER_NAME:-$(scutil --get LocalHostName 2>/dev/null || hostname -s)}
RUNNER_LABELS=${RUNNER_LABELS:-}

[[ "${DEDICATED_RUNNER:-}" == "1" ]] || die "set DEDICATED_RUNNER=1 and run with sudo -E"

echo "=== preflight ==="
set +e
pre_out=$(DEDICATED_RUNNER=1 RUNNER_USER="$RUNNER_USER" RUNNER_DIR="$RUNNER_DIR" FORCE="${FORCE:-}" \
  bash "$ROOT/macos/preflight.sh")
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
  bash "$ROOT/macos/verify.sh" || true
  exit 0
fi
if [[ "$decision" == "BLOCK" ]]; then
  exit 2
fi

require_env GITHUB_URL RUNNER_TOKEN

echo "=== keep awake ==="
pmset -a sleep 0 disksleep 0 displaysleep 0 || true
pmset -a disablesleep 1 2>/dev/null || true

echo "=== runner package ==="
arch=$(uname -m)
case "$arch" in
  arm64) pkg=osx-arm64; sum=$RUNNER_SHA256_OSX_ARM64 ;;
  x86_64) pkg=osx-x64; sum=$RUNNER_SHA256_OSX_X64 ;;
  *) die "unsupported arch $arch" ;;
esac
tarball="actions-runner-${pkg}-${RUNNER_VERSION}.tar.gz"
url="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/${tarball}"

install -d -o "$RUNNER_USER" -g "$(id -gn "$RUNNER_USER")" "$RUNNER_DIR"
if [[ ! -x "$RUNNER_DIR/config.sh" ]]; then
  tmp=$(mktemp)
  curl -fsSL -o "$tmp" "$url"
  assert_sha256 "$tmp" "$sum"
  tar -xzf "$tmp" -C "$RUNNER_DIR"
  rm -f "$tmp"
  chown -R "$RUNNER_USER:$(id -gn "$RUNNER_USER")" "$RUNNER_DIR"
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
  sudo -u "$RUNNER_USER" ./config.sh "${cfg[@]}"
else
  echo "already configured; skip config.sh"
fi

echo "=== LaunchDaemon ==="
cd "$RUNNER_DIR"
if [[ ! -f "$RUNNER_DIR/.service" ]]; then
  ./svc.sh install "$RUNNER_USER"
fi
./svc.sh start || true

echo "=== verify ==="
RUNNER_USER="$RUNNER_USER" RUNNER_DIR="$RUNNER_DIR" bash "$ROOT/macos/verify.sh"
echo INSTALL_OK
