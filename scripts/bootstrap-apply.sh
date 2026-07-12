#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export NIX_CONFIG='experimental-features = nix-command flakes'

nix flake check
nixos-rebuild build --flake .#hardy

printf 'Bootstrap apply .#hardy to this machine? [y/N] '
read -r answer
case "$answer" in
  y|Y|yes|YES)
    sudo env NIX_CONFIG="$NIX_CONFIG" nixos-rebuild switch --flake .#hardy
    ;;
  *)
    echo 'bootstrap apply aborted'
    exit 1
    ;;
esac
