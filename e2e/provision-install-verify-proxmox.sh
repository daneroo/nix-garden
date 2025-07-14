#!/usr/bin/env bash
set -euo pipefail

echo "# Script Start (provisioning side)"
echo ""


# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
PROXMOX_HOST="hilbert"
VMID="997"
ISO_FILENAME="my-nixos-25.05.20250618.9ba04bd-x86_64-linux.iso"

# ISO_FILENAME="clan-nixos÷-installer-x86_64-linux.iso"
# SSH options for convenience
# - ConnectTimeout=10: Prevent hanging by timing out after 10 seconds
# - StrictHostKeyChecking=no: Don't verify host keys (for automation)
# - UserKnownHostsFile=/dev/null: Don't store or use known hosts file
# - LogLevel=ERROR: Suppress warnings about unverified host keys
SSH_OPTS="-o ConnectTimeout=20 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

# Check if VMID already exists
echo "## Checking if VMID $VMID already exists..."
# awk finds VMID in first column, grep -q . checks if any output was produced
if ssh root@$PROXMOX_HOST "qm list | awk '\$1 == $VMID'" | grep -q .; then
    echo "✗ ERROR: VMID $VMID already exists on $PROXMOX_HOST"
    echo "  Please choose a different VMID or delete the existing VM first"
    echo "  To delete: ssh root@$PROXMOX_HOST 'qm stop $VMID && qm destroy $VMID'"
    exit 1
fi
echo "✓ VMID $VMID is available"
echo ""

# Execute local script on remote host with named parameters
# - $(...) captures command output into variable
# - ssh runs remote bash with script as input
# - tee /dev/tty shows output AND captures it
# - PIPESTATUS[0] gets SSH exit code
REMOTE_OUTPUT=$(ssh root@$PROXMOX_HOST 'bash -s --' "--iso" "$ISO_FILENAME" "--vmid" "$VMID" < "$SCRIPT_DIR/provision-on-proxmox.sh" | tee /dev/tty)
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

# Extract ISO_SHA256 from captured output
# - grep finds the line with ISOSHA256
# - sed removes everything before the hash
ISO_SHA256=$(echo "$REMOTE_OUTPUT" | grep "ISOSHA256:" | sed 's/.*ISOSHA256: //')
if [ -z "$ISO_SHA256" ]; then
    echo "✗ ERROR: Could not find ISOSHA256 in remote output"
    exit 1
fi
echo "- ISO_SHA256: ${ISO_SHA256}"

echo ""
echo "## SSHing into VM"
echo ""

echo "### Executing in Installer VM (as nixos)"
echo ""
ssh $SSH_OPTS nixos@${VM_IP} << 'EOF'
echo "OS Release: $(cat /etc/os-release | grep PRETTY_NAME)"
echo "System Info: $(uname -a)"

# When working on a feature branch, change this to your branch name
# Example: FLAKE_URI="github:daneroo/nix-garden/feature/your-branch-name"
FLAKE_URI="github:daneroo/nix-garden"
TARGET_HOST="minimal-amd64"
FLAKE_OUTPUT_REF="${FLAKE_URI}#${TARGET_HOST}"
echo "Flake URI: ${FLAKE_URI}"
echo "Target host: ${TARGET_HOST}"
echo "Flake output reference: ${FLAKE_OUTPUT_REF}"

# show the flake output reference nixosConfigurations
nix flake show ${FLAKE_URI} --json | jq '.nixosConfigurations | keys'

echo ""
echo "### Formatting disks with disko..."
echo ""
sudo nix run github:nix-community/disko -- --mode disko --flake ${FLAKE_OUTPUT_REF}

echo ""
echo "### Installing system with nixos-install..."
echo ""
sudo nixos-install --flake ${FLAKE_OUTPUT_REF} --no-root-passwd

# reboot and exit immediately to avoid SSH hanging
echo ""
echo "Rebooting system..."
sudo reboot & exit
EOF

# Wait for system to reboot and become available
echo "Waiting for system to reboot and become available..."
MAX_ATTEMPTS=10
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    echo "  - Attempt $ATTEMPT/$MAX_ATTEMPTS: Testing SSH connection..."
    
    # Use || true to prevent script failure with set -euo pipefail
    if ssh $SSH_OPTS daniel@${VM_IP} 'echo "SSH connection successful"' >/dev/null 2>&1 || true; then
        echo "✓ System is available after reboot"
        break
    fi
    
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "✗ WARNING: System not available after $MAX_ATTEMPTS attempts"
        echo "  You may need to connect manually to troubleshoot"
        break
    fi
    
    sleep 5
done

# Optional verification - only if system is responding
if [ $ATTEMPT -lt $MAX_ATTEMPTS ]; then
    echo ""
    echo "### System Verification (Installed NixOS as daniel)"
    echo ""
    ssh $SSH_OPTS daniel@${VM_IP} << 'EOF' || echo "✗ WARNING: Verification failed, but system seems to be running"
echo "OS Release: $(cat /etc/os-release | grep PRETTY_NAME)"
echo "System Info: $(uname -a)"
echo "NixOS Version: $(nixos-version)"
echo "Disk Usage: $(df -h / /tmp)"
echo "Memory Usage: $(free -h)"
echo "Uptime: $(uptime)"
EOF

    echo ""
    echo "### Rebuilding ISO from within installed system"
    echo ""
    ssh $SSH_OPTS daniel@${VM_IP} << EOF || echo "✗ WARNING: ISO rebuild verification failed"
# When working on a feature branch, change the branch name in the URI
# Example: github:daneroo/nix-garden/feature/your-branch-name#nixosConfigurations.installer-x86_64.config.system.build.images.iso-installer
echo "Building ISO from GitHub repo..."
nix build --quiet github:daneroo/nix-garden#nixosConfigurations.installer-x86_64.config.system.build.images.iso-installer

echo "Extracting new ISO SHA256..."
NEW_ISO_SHA256=\$(sha256sum ./result/iso/*.iso | awk '{print \$1}')
echo "NEW_ISO_SHA256: \$NEW_ISO_SHA256"

echo "Comparing with original ISO SHA256: $ISO_SHA256"
if [ "\$NEW_ISO_SHA256" = "$ISO_SHA256" ]; then
    echo "✓ SHAs match - reproducible build achieved!"
else
    echo "✗ SHAs differ - manual intervention required"
    echo "  Original: $ISO_SHA256"
    echo "  New:      \$NEW_ISO_SHA256"
    echo "  To converge: manually copy new ISO to $PROXMOX_HOST and re-run this script"
fi
EOF

    echo ""
    echo "### Copying built ISO from VM"
    echo ""
    echo "Copying ISO from daniel@${VM_IP}:result/iso/nixos-*-x86_64-linux.iso"
    if scp $SSH_OPTS daniel@${VM_IP}:result/iso/nixos-*-x86_64-linux.iso .; then
        echo "✓ ISO copied successfully to current directory"
        ls -la nixos-*-x86_64-linux.iso
        
        # Rename to expected filename format (add "my-" prefix)
        echo "Renaming ISO to expected format..."
        BUILT_ISO_NAME=$(ls nixos-*-x86_64-linux.iso)
        mv "$BUILT_ISO_NAME" "my-$BUILT_ISO_NAME"
        echo "✓ ISO renamed to: my-$BUILT_ISO_NAME"
        ls -la "my-$BUILT_ISO_NAME"
    else
        echo "✗ ERROR: Failed to copy built ISO from VM"
        echo "  Manual copy required: scp $SSH_OPTS daniel@${VM_IP}:result/iso/nixos-*-x86_64-linux.iso ."
    fi

    echo ""
    echo "### Connection Information"
    echo ""
    echo "To connect to the VM (installer):"
    echo "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR nixos@${VM_IP}"
    echo "To connect to the VM (installed for daniel):"
    echo "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR daniel@${VM_IP}"
    echo ""
else
    echo ""
    echo "✗ WARNING: System verification skipped - VM not responding"
    echo ""
    echo "### Connection Information (for manual troubleshooting)"
    echo ""
    echo "To connect to the VM (installer):"
    echo "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR nixos@${VM_IP}"
    echo "To connect to the VM (installed for daniel):"
    echo "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR daniel@${VM_IP}"
    echo ""
fi


echo "## Completion"
echo ""
echo "✓ Script completed successfully (provisioning side)"
echo ""

