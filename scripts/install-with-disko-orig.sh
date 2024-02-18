#!/usr/bin/env bash

set -euo pipefail
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

TARGET_HOST="${1:-}"
TARGET_USER="${2:-jon}"

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR! $(basename "${0}") should be run as a regular user"
  exit 1
fi

if [[ -z "$TARGET_HOST" ]]; then
    echo "ERROR! $(basename "${0}") requires a hostname as the first argument"
    exit 1
fi

if [ ! -e "host/${TARGET_HOST}/disks.nix" ]; then
  echo "ERROR! $(basename "${0}") could not find the required host/${TARGET_HOST}/disks.nix"
  exit 1
fi

# Check if the machine we're provisioning expects a keyfile to unlock a disk.
# If it does, generate a new key, and write to a known location.
if grep -q "data.keyfile" "host/${TARGET_HOST}/disks.nix"; then
  echo -n "$(head -c32 /dev/random | base64)" > /tmp/data.keyfile
fi

echo "WARNING! The disks in ${TARGET_HOST} are about to get wiped"
echo "         NixOS will be re-installed"
echo "         This is a destructive operation"
echo
read -p "Are you sure? [y/N]" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo true

    sudo nix run github:nix-community/disko \
        --extra-experimental-features "nix-command flakes" \
        --no-write-lock-file \
        -- \
        --mode zap_create_mount \
        "host/${TARGET_HOST}/disks.nix"

    sudo nixos-install --flake ".#${TARGET_HOST}"

    # Rsync my nix-config to the target install
    mkdir -p "/mnt/home/${TARGET_USER}/nixos-config"
    rsync -a --delete "${DIR}/.." "/mnt/home/${TARGET_USER}/nixos-config"

    # If there is a keyfile for a data disk, put copy it to the root partition and
    # ensure the permissions are set appropriately.
    if [[ -f "/tmp/data.keyfile" ]]; then
      sudo cp /tmp/data.keyfile /mnt/etc/data.keyfile
      sudo chmod 0400 /mnt/etc/data.keyfile
    fi
fi

