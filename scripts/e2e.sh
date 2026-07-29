#!/usr/bin/env bash

set -euo pipefail

fail() {
  printf 'e2e: %s\n' "$*" >&2
  exit 1
}

if [[ $# -ne 0 ]]; then
  fail "this command takes no arguments"
fi

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
  "Do not type or change workspaces until the suite restores focus."

gum confirm \
  --default=false \
  "Run the desktop E2E suite on the current workspace?" ||
  fail "cancelled without changing the desktop"

gum style "keyd evidence requires sudo for this run."
sudo -v || fail "sudo authorization failed"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$script_dir/../tests/e2e/bun" && pwd)"

cd -- "$project_dir"
exec bun run test
