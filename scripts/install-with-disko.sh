#!/usr/bin/env bash

set -euo pipefail
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


TARGET_HOST="${1}"
if [ -z "${TARGET_HOST}" ]; then
  echo "ERROR! ${0} requires a target host as the first argument"
  exit 1
fi
DISKO_NIX="host/${TARGET_HOST}/disks.nix"

EXEC_NAME=$(basename "${0}")
echo "Running ${EXEC_NAME} host: ${TARGET_HOST} disko: ${DISKO_NIX}"

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

    # Usage: diskko [options] disk-config.nix
    # or disko [options] --flake github:somebody/somewhere#disk-config

    # set the mode, either format, mount or disko
    #   format: create partition tables, zpools, lvms, raids and filesystems
    #   mount: mount the partition at the specified root-mountpoint
    #   disko: first unmount and destroy all filesystems on the disks we want to format, then run the create and mount mode

    # run disko
    sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko "${DISKO_NIX}"

    # Install NixOS
    echo "Installing NixOS (${TARGET_HOST})"
    # make sure  you set passwd/authorizedKeys in configuration.nix if you use --no-root-passwd
    sudo nixos-install --flake ".#${TARGET_HOST}" --no-root-passwd

    # Reboot
    echo "Remove the installation media (or adjust boot priority) and reboot"
fi

