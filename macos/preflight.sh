#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../shared/lib.sh
source "$ROOT/shared/lib.sh"

RUNNER_USER=${RUNNER_USER:-${SUDO_USER:-$(id -un)}}
RUNNER_DIR=${RUNNER_DIR:-/Users/${RUNNER_USER}/actions-runner}

os_kernel=$(uname -s)
os_arch=$(uname -m)
emit os "$(echo "$os_kernel" | tr '[:upper:]' '[:lower:]')"
emit arch "$os_arch"
emit dedicated "${DEDICATED_RUNNER:-0}"
emit runner_dir "$RUNNER_DIR"

if [[ "$os_kernel" != "Darwin" ]]; then
  decide BLOCK not_macos
  exit $?
fi

emit macos "$(sw_vers -productVersion 2>/dev/null || echo unknown)"
emit product "$(sw_vers -productName 2>/dev/null || echo unknown)"

clt=false
if xcode-select -p >/dev/null 2>&1; then
  clt=true
fi
emit xcode_clt "$clt"

listeners=$(listener_count)
emit listeners "$listeners"
already=false
[[ -f "$RUNNER_DIR/.runner" ]] && already=true
emit already_configured "$already"

if ! dedicated_ok; then
  decide SKIP not_dedicated_host
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

if [[ "$clt" != true ]]; then
  decide BLOCK xcode_clt_missing
  exit $?
fi

decide APPLY
exit $?
