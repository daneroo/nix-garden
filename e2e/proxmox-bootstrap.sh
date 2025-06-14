#!/usr/bin/env bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
PROXMOX_HOST="hilbert"
VMID="997"
ISO_PATH="/pve-storage/backups-isos/template/iso/my-nixos-25.05.20250605.4792576-x86_64-linux.iso"

# Execute local script on remote host with named parameters
ssh root@$PROXMOX_HOST 'bash -s --' "--iso" "$ISO_PATH" "--vmid" "$VMID" < "$SCRIPT_DIR/local-script-for-remote-execution.sh" 