#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'e2e: %s\n' "$*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: ./scripts/e2e.sh [-y|--yes] [--slow [SECONDS]]

  -y, --yes        accept the guarded workspace and clipboard confirmation
  --slow [SECONDS] pause at labelled visual checkpoints (default: 1 second)
  -h, --help       show this help
EOF
}

assume_yes=false
slow_seconds=0
while [[ $# -gt 0 ]]; do
  case $1 in
    -y | --yes)
      assume_yes=true
      shift
      ;;
    --slow)
      slow_seconds=1
      if [[ $# -gt 1 && $2 != -* ]]; then
        slow_seconds=$2
        shift
      fi
      shift
      ;;
    --slow=*)
      slow_seconds=${1#--slow=}
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ $slow_seconds =~ ^[0-9]+([.][0-9]+)?$ ]] ||
  fail "--slow requires a non-negative number of seconds"

for executable in bun gum sudo; do
  command -v "$executable" >/dev/null 2>&1 ||
    fail "required executable is unavailable: $executable"
done

[[ $(id -un) == "daniel" ]] ||
  fail "run this suite as Daniel, not $(id -un)"
[[ ${XDG_SESSION_TYPE-} == "wayland" ]] ||
  fail "XDG_SESSION_TYPE must identify the active Wayland session"
[[ -n ${XDG_RUNTIME_DIR-} && -n ${WAYLAND_DISPLAY-} ]] ||
  fail "the graphical session environment is incomplete"
[[ -n ${DBUS_SESSION_BUS_ADDRESS-} ]] ||
  fail "the user D-Bus address is unavailable"
[[ -t 0 && -t 1 ]] ||
  fail "the guarded entry point requires an interactive terminal"

gum style \
  --bold \
  --foreground 212 \
  "nix-garden desktop E2E"
gum style \
  "This suite will take control of the visible desktop." \
  "It will focus fixture windows and inject physical keyboard chords." \
  "It will overwrite the clipboard and will not restore it (cleared at the end)." \
  "Do not type or change workspaces until the suite restores focus."

if [[ $assume_yes == false ]]; then
  gum confirm \
    --default=false \
    "Run on this workspace and overwrite the clipboard?" ||
    fail "cancelled without changing the desktop"
fi

if sudo -n true 2>/dev/null; then
  gum style "sudo authorization is already available for keyd evidence."
else
  gum style \
    "sudo authorization is required for keyd evidence." \
    "Enter your password when prompted, or press Ctrl+C to abort before desktop control."
  sudo -v || fail "sudo authorization failed"
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/../tests/e2e/bun" && pwd)"

export NIX_GARDEN_E2E_SLOW_SECONDS=$slow_seconds

cd -- "$project_dir"
exec bun run test
