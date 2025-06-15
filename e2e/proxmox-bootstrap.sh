#!/usr/bin/env bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
PROXMOX_HOST="hilbert"
VMID="997"
ISO_FILENAME="my-nixos-25.05.20250605.4792576-x86_64-linux.iso"

# Execute local script on remote host with named parameters
ssh root@$PROXMOX_HOST 'bash -s --' "--iso" "$ISO_FILENAME" "--vmid" "$VMID" < "$SCRIPT_DIR/local-script-for-remote-execution.sh" 