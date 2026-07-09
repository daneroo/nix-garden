#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== shell syntax =="
bash -n scripts/*.sh

echo
echo "== flake check =="
nix flake check

# Add Markdown and Nix format/lint checks here as the toolchain settles.
