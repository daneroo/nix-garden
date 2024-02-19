#!/usr/bin/env bash

set -euo pipefail
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

DISKO_NIX="${2:-./disk-config.nix}"

echo "WARNING! The disks are about to get wiped"
echo "         NixOS will be re-installed"
echo "         This is a destructive operation"
echo
read -p "Are you sure? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo true

    # run disko
    echo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko "${DISKO_NIX}"
    sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko "${DISKO_NIX}"
fi

