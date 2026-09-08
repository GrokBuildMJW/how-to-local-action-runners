#!/usr/bin/env bash
# Host eligibility. Prints KEY=value facts and a final DECISION= line.
# Exit 0 = APPLY or SKIP; 2 = BLOCK; 1 = script error.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../shared/lib.sh
source "$ROOT/shared/lib.sh"

PROFILE=${PROFILE:-docker-jobs}
RUNNER_USER=${RUNNER_USER:-${SUDO_USER:-runner}}
RUNNER_DIR=${RUNNER_DIR:-/home/${RUNNER_USER}/actions-runner}

os_kernel=$(uname -s)
os_arch=$(uname -m)
emit os "$(echo "$os_kernel" | tr '[:upper:]' '[:lower:]')"
emit arch "$os_arch"
emit profile "$PROFILE"
emit dedicated "${DEDICATED_RUNNER:-0}"
emit runner_dir "$RUNNER_DIR"

if [[ "$os_kernel" != "Linux" ]]; then
  decide BLOCK not_linux
  exit $?
fi

ID= VERSION_ID= VERSION_CODENAME=
if [[ -f /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
fi
emit distro "${ID:-unknown}"
emit version "${VERSION_ID:-unknown}"
emit codename "${VERSION_CODENAME:-unknown}"

kernel_rel=$(uname -r)
emit kernel "$kernel_rel"
kernel_major=${kernel_rel%%.*}
kernel_rest=${kernel_rel#*.}
kernel_minor=${kernel_rest%%.*}
emit kernel_major "$kernel_major"
emit kernel_minor "$kernel_minor"

listeners=$(listener_count)
emit listeners "$listeners"
already=false
if [[ -f "$RUNNER_DIR/.runner" ]]; then
  already=true
fi
emit already_configured "$already"

apparmor_dir=false
[[ -d /sys/kernel/security/apparmor ]] && apparmor_dir=true
emit apparmor_fs "$apparmor_dir"
cmdline_aa=false
if [[ -f /proc/cmdline ]] && grep -qw apparmor=0 /proc/cmdline; then
  cmdline_aa=true
fi
emit apparmor_cmdline_off "$cmdline_aa"

if ! dedicated_ok; then
  decide SKIP not_dedicated_host
  exit $?
fi

if [[ "$PROFILE" != "docker-jobs" && "$PROFILE" != "minimal" ]]; then
  decide BLOCK unknown_profile
  exit $?
fi

if [[ "$already" == true && "$listeners" -ge 1 && "${FORCE:-}" != "1" ]]; then
  decide SKIP already_configured
  exit $?
fi

if [[ "$listeners" -ge 1 && "$already" != true ]]; then
  decide BLOCK listener_conflict
  exit $?
fi
if [[ "$listeners" -ge 2 ]]; then
  decide BLOCK listener_conflict
  exit $?
fi

if [[ "$PROFILE" == "docker-jobs" ]]; then
  if [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "26.04" ]]; then
    decide BLOCK ubuntu_26_04
    exit $?
  fi
  if [[ "${ID:-}" == "ubuntu" && "${VERSION_ID:-}" == "24.04" ]]; then
    if [[ "$kernel_rel" == 6.8.* ]]; then
      emit kernel_pin_needed false
    else
      emit kernel_pin_needed true
    fi
  elif [[ "$kernel_major" -ge 7 ]]; then
    decide BLOCK kernel_7
    exit $?
  fi
fi

decide APPLY
exit $?
