#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

section() {
  printf '\n## %s\n\n```text\n' "$1"
  shift
  "$@" 2>&1 || true
  printf '```\n'
}

printf '# Hardy Host Audit\n'
printf '\nGenerated: %s\n' "$(date --iso-8601=seconds)"
printf '\nReview before committing; this report intentionally omits network addresses, keys, serial numbers, and environment variables.\n'

section "Identity" sh -c 'hostnamectl 2>/dev/null || hostname; printf "NixOS: "; nixos-version'
section "Running System" sh -c '
  printf "current: "; readlink -f /run/current-system
  printf "booted:  "; readlink -f /run/booted-system
  printf "profile: "; readlink -f /nix/var/nix/profiles/system
'
section "Generations" nix-env --profile /nix/var/nix/profiles/system --list-generations
section "SSH" sh -c '
  printf "enabled: "; systemctl is-enabled sshd
  printf "active:  "; systemctl is-active sshd
'
section "Filesystems" findmnt --real --output TARGET,SOURCE,FSTYPE,OPTIONS
section "Block Devices" lsblk --output NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
section "Repository" sh -c '
  printf "root: "; pwd
  printf "branch: "; git branch --show-current
  printf "head: "; git rev-parse HEAD
  git status --short --branch
  git remote --verbose
  git log --oneline --decorate -5
'
