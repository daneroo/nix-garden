#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

blessed_hosts=(hardy gauss)
host="$(hostname)"
blessed=false
for h in "${blessed_hosts[@]}"; do
  [[ "$h" == "$host" ]] && blessed=true
done
if [[ "$blessed" != true ]]; then
  echo "unrecognized hostname '$host'; blessed hosts: ${blessed_hosts[*]}" >&2
  exit 1
fi
flake=".#$host"

export NIX_CONFIG='experimental-features = nix-command flakes'

nix flake check
nixos-rebuild build --flake "$flake"

printf 'Bootstrap apply %s to this machine? [y/N] ' "$flake"
read -r answer
case "$answer" in
  y|Y|yes|YES)
    sudo env NIX_CONFIG="$NIX_CONFIG" nixos-rebuild switch --flake "$flake"
    ;;
  *)
    echo 'bootstrap apply aborted'
    exit 1
    ;;
esac
