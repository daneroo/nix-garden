#!/usr/bin/env bash
set -euo pipefail

echo "# Script Start (provisioning side)"
echo ""


# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
PROXMOX_HOST="hilbert"
VMID="997"
ISO_FILENAME="my-nixos-25.05.20250605.4792576-x86_64-linux.iso"

# Execute local script on remote host with named parameters
# - $(...) captures command output into variable
# - ssh runs remote bash with script as input
# - tee /dev/tty shows output AND captures it
# - PIPESTATUS[0] gets SSH exit code
REMOTE_OUTPUT=$(ssh root@$PROXMOX_HOST 'bash -s --' "--iso" "$ISO_FILENAME" "--vmid" "$VMID" < "$SCRIPT_DIR/local-script-for-remote-execution.sh" | tee /dev/tty)
SSH_EXIT_CODE=${PIPESTATUS[0]}

if [ $SSH_EXIT_CODE -ne 0 ]; then
    echo "✗ ERROR: Remote script failed with exit code $SSH_EXIT_CODE"
    exit $SSH_EXIT_CODE
fi

echo "## Extracting Information from Remote Output"
echo ""

# Extract TARGET_MAC from captured output
# - grep finds the line with TARGET_MAC
# - sed removes everything before the MAC
TARGET_MAC=$(echo "$REMOTE_OUTPUT" | grep "TARGET_MAC:" | sed 's/.*TARGET_MAC: //')
if [ -z "$TARGET_MAC" ]; then
    echo "✗ ERROR: Could not find TARGET_MAC in remote output"
    exit 1
fi
echo "- TARGET_MAC: ${TARGET_MAC}"

# Extract VM_IP from captured output
# - grep finds the line with VM_IP
# - sed removes everything before the IP
VM_IP=$(echo "$REMOTE_OUTPUT" | grep "VM_IP:" | sed 's/.*VM_IP: //')
if [ -z "$VM_IP" ]; then
    echo "✗ ERROR: Could not find VM_IP in remote output"
    exit 1
fi
echo "- VM_IP: ${VM_IP}"

echo ""
echo "## SSHing into VM"
echo ""
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR nixos@${VM_IP} cat /etc/os-release
echo ""
echo ""
echo "To connect to the VM:"
echo "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR nixos@${VM_IP}"
echo ""


echo "## Completion"
echo ""
echo "✓ Script completed successfully (provisioning side)"
echo ""

