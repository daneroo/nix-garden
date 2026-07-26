#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: current-state.sh [-v|--verbose]
       current-state.sh -h|--help

Compare the running system with this nix-garden checkout.

  nix: NIXOS_VERSION@CONFIG_REV
        The active NixOS version (ending in the nixpkgs revision prefix)
        and the nix-garden Git revision that built the running system.
        Off NixOS, this becomes lock/NIXPKGS_REV from flake.lock.

  git: BRANCH/DESCRIBE
        The checkout branch and `git describe --tags --always --dirty`.

Options:
  -v, --verbose  Show an annotated diagram of the live values.
  -h, --help     Show this explanation.
EOF
}

verbose=false
case "${1:-}" in
  "")
    ;;
  -v | --verbose)
    verbose=true
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    printf "current-state.sh: unknown option: %s\n" "$1" >&2
    printf "Try 'current-state.sh --help'.\n" >&2
    exit 2
    ;;
esac

if (($# > 1)); then
  printf "current-state.sh: expected at most one option\n" >&2
  printf "Try 'current-state.sh --help'.\n" >&2
  exit 2
fi

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
host_name="$(hostname -s)"

if command -v nixos-version >/dev/null 2>&1; then
  running_nixos=true
  read -r nixos_version configuration_revision < <(
    nixos-version --json |
      jq -r '[.nixosVersion, (.configurationRevision // "unknown")] | @tsv'
  )
  nix_state="${nixos_version}@${configuration_revision:0:7}"
else
  running_nixos=false
  nixpkgs_revision="$(
    jq -r \
      '.nodes[.nodes[.root].inputs.nixpkgs].locked.rev // "unknown"' \
      "$repo_root/flake.lock"
  )"
  nix_state="lock/${nixpkgs_revision:0:7}"
fi

branch="$(git -C "$repo_root" branch --show-current)"
if [[ -z "$branch" ]]; then
  branch="detached"
fi
describe="$(git -C "$repo_root" describe --tags --always --dirty)"

printf "%-7s nix: %s  git: %s/%s\n" \
  "$host_name" "$nix_state" "$branch" "$describe"

if [[ "$verbose" == true ]]; then
  echo
  if [[ "$running_nixos" == true ]]; then
    printf "nix\n"
    printf "  %s @ %.7s\n" "$nixos_version" "$configuration_revision"
    printf "  \\_____________________/   \\_____/\n"
    printf "       nixosVersion          configurationRevision\n"
    printf "       (ends in nixpkgs)     (running nix-garden Git)\n"
  else
    printf "nix\n"
    printf "  lock / %.7s\n" "$nixpkgs_revision"
    printf "  \\__/   \\_____/\n"
    printf "  no NixOS  root nixpkgs pin from flake.lock\n"
  fi
  printf "\n"
  printf "git\n"
  printf "  %s / %s\n" "$branch" "$describe"
  printf "  \\____/   \\____________/\n"
  printf "  branch    git describe --tags --always --dirty\n"
fi
