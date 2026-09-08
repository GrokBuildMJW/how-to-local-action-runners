#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../shared/lib.sh
source "$ROOT/shared/lib.sh"

PROFILE=${PROFILE:-docker-jobs}
RUNNER_USER=${RUNNER_USER:-${SUDO_USER:-runner}}
RUNNER_DIR=${RUNNER_DIR:-/home/${RUNNER_USER}/actions-runner}

fail=0
ok() { echo "ok: $*"; }
bad() { echo "FAIL: $*" >&2; fail=1; }

[[ -f "$RUNNER_DIR/.runner" ]] && ok "registration $RUNNER_DIR/.runner" || bad "missing $RUNNER_DIR/.runner"
[[ -x "$RUNNER_DIR/run.sh" ]] && ok "runner binaries" || bad "missing $RUNNER_DIR/run.sh"

n=$(listener_count || true)
n=${n:-0}
if [[ "$n" == "1" ]]; then
  ok "exactly one Runner.Listener"
else
  bad "expected 1 Runner.Listener, have $n"
  listener_cmds >&2 || true
fi

unit=""
if [[ -f "$RUNNER_DIR/.service" ]]; then
  unit=$(tr -d '\r' <"$RUNNER_DIR/.service" | awk -F= '/^name=/{print $2; exit}')
fi
if [[ -z "$unit" ]]; then
  unit=$(systemctl list-units --type=service --all 'actions.runner.*' --no-legend 2>/dev/null | awk '{print $1}' | head -1)
fi
if [[ -n "$unit" ]]; then
  systemctl is-active --quiet "$unit" && ok "systemd $unit active" || bad "systemd $unit not active"
  systemctl is-enabled --quiet "$unit" && ok "systemd $unit enabled" || bad "systemd $unit not enabled"
  cgroup=$(ps -eo cgroup,cmd | awk '/[R]unner.Listener/{print $1; exit}')
  if [[ "$cgroup" == *docker-* ]]; then
    bad "listener is in a docker cgroup: $cgroup"
  else
    ok "listener cgroup is not docker"
  fi
else
  bad "no actions.runner systemd unit"
fi

if [[ "$PROFILE" == "docker-jobs" ]]; then
  command -v docker >/dev/null && ok "docker on PATH" || bad "docker missing"
  if command -v docker >/dev/null; then
    docker info >/dev/null 2>&1 && ok "docker info" || bad "docker info failed"
  fi
  if [[ -f /etc/docker/daemon.json ]] && grep -q apparmor-profile /etc/docker/daemon.json; then
    bad "/etc/docker/daemon.json has apparmor-profile (Docker 29 rejects it)"
  else
    ok "no apparmor-profile in daemon.json"
  fi
  k=$(uname -r)
  if [[ "$k" == 6.8.* ]]; then
    ok "kernel $k (GA 6.8)"
  else
    bad "kernel $k is not 6.8.x — see linux/KERNEL.md"
  fi
  if grep -qw apparmor=0 /proc/cmdline && [[ ! -d /sys/kernel/security/apparmor ]]; then
    ok "AppArmor off (cmdline + no securityfs)"
  else
    bad "AppArmor still present; docker-jobs needs apparmor=0 after reboot"
  fi
  sysctl -n kernel.unprivileged_userns_clone >/dev/null 2>&1 && ok "userns sysctl present" || true
fi

if [[ "$fail" -ne 0 ]]; then
  echo VERIFY_FAIL
  exit 1
fi
echo VERIFY_OK
