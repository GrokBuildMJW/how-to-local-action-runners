# shellcheck shell=bash
# Shared helpers for linux/ and macos/ scripts.

emit() {
  printf '%s=%s\n' "$1" "$2"
}

decide() {
  local d=$1
  local r=${2:-}
  if [[ -n "$r" ]]; then
    printf 'DECISION=%s reason=%s\n' "$d" "$r"
  else
    printf 'DECISION=%s\n' "$d"
  fi
  case "$d" in
    APPLY|SKIP) return 0 ;;
    BLOCK) return 2 ;;
    *) return 1 ;;
  esac
}

die() {
  echo "error: $*" >&2
  exit 1
}

need_root() {
  if [[ $(id -u) -ne 0 ]]; then
    die "run as root (sudo -E $0)"
  fi
}

repo_root() {
  local here
  here=$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)
  cd "$here/.." && pwd
}

load_pins() {
  local f=$1
  [[ -f "$f" ]] || die "missing pins file: $f"
  # shellcheck disable=SC1090
  set -a
  # shellcheck disable=SC1090
  source "$f"
  set +a
}

require_env() {
  local n
  for n in "$@"; do
    [[ -n "${!n:-}" ]] || die "set $n"
  done
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

assert_sha256() {
  local file=$1
  local expect=$2
  local got
  got=$(sha256_of "$file")
  if [[ "$got" != "$expect" ]]; then
    rm -f "$file"
    die "SHA-256 mismatch for $file: got $got want $expect"
  fi
}

listener_count() {
  local n=0
  n=$(pgrep -f '[R]unner.Listener' 2>/dev/null | wc -l | tr -d ' ') || n=0
  printf '%s\n' "${n:-0}"
}

listener_cmds() {
  pgrep -af '[R]unner.Listener' 2>/dev/null || true
}

dedicated_ok() {
  [[ "${DEDICATED_RUNNER:-}" == "1" ]]
}

looks_like_workstation() {
  # Heuristic only. DEDICATED_RUNNER=1 overrides.
  if dedicated_ok; then
    return 1
  fi
  if [[ -d /home && -n "$(ls /home/*/cursor-agent 2>/dev/null || true)" ]]; then
    return 0
  fi
  if command -v gnome-shell >/dev/null 2>&1 && [[ -d /var/lib/snapd ]]; then
    return 0
  fi
  return 1
}
