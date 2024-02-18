#!/usr/bin/env bash

set -euo pipefail
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

TARGET_HOST="${1:-}"
TARGET_USER="${2:-daniel}"
DISKO_NIX="${3:-./disks.nix}"

echo "Running $(basename "${0}") host: ${TARGET_HOST} user: ${TARGET_USER} diskonix: ${DISKO_NIX}"

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR! $(basename "${0}") should be run as a regular user"
  exit 1
fi

if [[ -z "$TARGET_HOST" ]]; then
    echo "ERROR! $(basename "${0}") requires a hostname as the first argument"
    exit 1
fi

# if [ ! -e "host/${TARGET_HOST}/disks.nix" ]; then
#   echo "ERROR! $(basename "${0}") could not find the required host/${TARGET_HOST}/disks.nix"
#   exit 1
# fi
if [ ! -e "${DISKO_NIX}" ]; then
  echo "ERROR! $(basename "${0}") could not find the required ${DISKO_NIX}"
  exit 1
fi


echo "WARNING! The disks in ${TARGET_HOST} are about to get wiped"
echo "         NixOS will be re-installed"
echo "         This is a destructive operation"
echo
read -p "Are you sure? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo true

    # run disko
    sudo nix run github:nix-community/disko \
        --extra-experimental-features "nix-command flakes" \
        --no-write-lock-file \
        -- \
        --mode zap_create_mount \
        "host/${TARGET_HOST}/disks.nix"

    # Install NixOS
    echo "NOT Installing NixOS"
    # sudo nixos-install --flake ".#${TARGET_HOST}"

    # Rsync my nix-config to the target install
    echo "NOT Rsyncing nixos-config to /mnt/home/${TARGET_USER}/nixos-config"
    # mkdir -p "/mnt/home/${TARGET_USER}/nixos-config"
    # rsync -a --delete "${DIR}/.." "/mnt/home/${TARGET_USER}/nixos-config"
fi
