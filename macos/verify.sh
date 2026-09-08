#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../shared/lib.sh
source "$ROOT/shared/lib.sh"

RUNNER_USER=${RUNNER_USER:-${SUDO_USER:-$(id -un)}}
RUNNER_DIR=${RUNNER_DIR:-/Users/${RUNNER_USER}/actions-runner}

fail=0
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; fail=1; }

[[ -f "$RUNNER_DIR/.runner" ]] && ok "registration $RUNNER_DIR/.runner" || bad "missing $RUNNER_DIR/.runner"
[[ -x "$RUNNER_DIR/run.sh" ]] && ok "runner binaries" || bad "missing $RUNNER_DIR/run.sh"

n=$(listener_count)
if [[ "$n" == "1" ]]; then
  ok "exactly one Runner.Listener"
else
  bad "expected 1 Runner.Listener, have $n"
  listener_cmds >&2 || true
fi

if [[ -f "$RUNNER_DIR/.service" ]]; then
  svc=$(tr -d '\r' <"$RUNNER_DIR/.service" | awk -F= '/^name=/{print $2; exit}')
  if [[ -n "$svc" ]]; then
    if launchctl print "system/$svc" >/dev/null 2>&1 || launchctl print "gui/$(id -u "$RUNNER_USER")/$svc" >/dev/null 2>&1; then
      ok "launchd $svc loaded"
    else
      # svc.sh status is the supported check
      if [[ -x "$RUNNER_DIR/svc.sh" ]] && "$RUNNER_DIR/svc.sh" status >/dev/null 2>&1; then
        ok "svc.sh status ok ($svc)"
      else
        bad "launchd service $svc not loaded"
      fi
    fi
  fi
else
  bad "missing $RUNNER_DIR/.service (LaunchDaemon not installed)"
fi

if [[ "$fail" -ne 0 ]]; then
  echo VERIFY_FAIL
  exit 1
fi
echo VERIFY_OK
