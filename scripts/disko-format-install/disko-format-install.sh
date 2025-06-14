#!/usr/bin/env bash

set -eo pipefail
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

FLAKE_URI="github:daneroo/nix-garden"

TARGET_HOST="${1}"
if [ -z "${TARGET_HOST}" ]; then
  echo "ERROR! ${0} requires a target host as the first argument"
  echo "Should be one of:"
  nix flake show ${FLAKE_URI}
  echo "Should be one of: (jq)"
  nix flake show ${FLAKE_URI} --json | jq '.nixosConfigurations | keys'
  echo "$(gum --version)"
  exit 1
fi

EXEC_NAME=$(basename "${0}")
FLAKE_OUTPUT_REF="${FLAKE_URI}#${TARGET_HOST}"
echo "Running ${EXEC_NAME} flake: ${FLAKE_URI} host: ${TARGET_HOST}"
echo " Flake output reference: ${FLAKE_OUTPUT_REF}"

if [ "$(id -u)" -eq 0 ]; then
  echo "ERROR! ${EXEC_NAME} should be run as a regular user"
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

    # nix run github:nix-community/disko -- --help
    sudo nix run github:nix-community/disko -- --mode disko --flake ${FLAKE_OUTPUT_REF}

    # Install NixOS
    echo "Installing NixOS (${TARGET_HOST})"
    # make sure  you set passwd/authorizedKeys in configuration.nix if you use --no-root-passwd
    # sudo nixos-install --flake ".#${TARGET_HOST}" --no-root-passwd
    sudo nixos-install --flake ${FLAKE_OUTPUT_REF} --no-root-passwd

    # Reboot
    echo "Remove the installation media (or adjust boot priority) and reboot"
fi

