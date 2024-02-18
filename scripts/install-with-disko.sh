#!/usr/bin/env bash

set -euo pipefail
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

TARGET_USER="${1:-daniel}"
DISKO_NIX="${2:-../disks/simple-efi.nix}"
EXEC_NAME=$(basename "${0}")
echo "Running ${EXEC_NAME} user: ${TARGET_USER} diskonix: ${DISKO_NIX}"

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR! ${EXEC_NAME} should be run as a regular user"
  exit 1
fi


if [ ! -e "${DISKO_NIX}" ]; then
  echo "ERROR! ${EXEC_NAME} could not find the required ${DISKO_NIX}"
  exit 1
fi


echo "WARNING! The disks are about to get wiped"
echo "         NixOS will be re-installed"
echo "         This is a destructive operation"
echo
read -p "Are you sure? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo true

    # run disko
    sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko "${DISKO_NIX}"
    # sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode zap_create_mount "${DISKO_NIX}"

    # Install NixOS
    echo "NOT Installing NixOS"
    # sudo nixos-install --flake ".#${TARGET_HOST}"
    sudo nixos-install --flake ".#nix-full"

    # Rsync my nix-config to the target install
    echo "NOT Rsyncing nixos-config to /mnt/home/${TARGET_USER}/nixos-config"
    # mkdir -p "/mnt/home/${TARGET_USER}/nixos-config"
    # rsync -a --delete "${DIR}/.." "/mnt/home/${TARGET_USER}/nixos-config"
fi

