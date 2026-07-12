#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "== shell syntax =="
bash -n scripts/*.sh

echo
echo "== formatting =="
just fmt-check

echo
echo "== markdown lint =="
just lint-md

echo
echo "== flake check =="
nix flake check
