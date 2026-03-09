#!/usr/bin/env bash
set -euo pipefail

# Configuration
PROXMOX_HOST="hilbert"
VM_ID="996"
MODE="img"  # "img" = cloud image (fast), "iso" = installer (fallback)
ISO_FILENAME="ubuntu-24.04.4-live-server-amd64.iso"
IMG_FILENAME="noble-server-cloudimg-amd64.img"
SEED_FILENAME="ubuntu-rdp-seed-$(date +%s).iso"   # ISO mode only

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_OPTS="-o ConnectTimeout=20 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes -o PasswordAuthentication=no"
ISO_PATH="/pve-storage/backups-isos/template/iso"

echo "# Ubuntu RDP Provision"
echo "- Host:  $PROXMOX_HOST"
echo "- VM_ID: $VM_ID"
echo "- Mode:  $MODE"
echo ""

if [[ "$MODE" == "img" ]]; then
    # -- Cloud image: Proxmox handles cloud-init natively --
    echo "## Provisioning VM from cloud image..."
    REMOTE_OUTPUT=$(ssh root@$PROXMOX_HOST 'bash -s --' \
        "--img" "$IMG_FILENAME" \
        "--vmid" "$VM_ID" \
        < "$SCRIPT_DIR/on-proxmox-img.sh" | tee /dev/tty)
else
    # -- ISO installer: build seed ISO, extract kernel, direct boot --
    echo "- ISO:   $ISO_FILENAME"
    echo "- Seed:  $SEED_FILENAME"
    echo ""

    echo "## Building seed ISO on $PROXMOX_HOST..."
    ssh root@$PROXMOX_HOST "
        cat > /tmp/user-data << 'USERDATA'
$(cat "$SCRIPT_DIR/on-proxmox-iso-seed.yaml")
USERDATA
        echo '' > /tmp/meta-data
        genisoimage -output '$ISO_PATH/$SEED_FILENAME' \
            -volid cidata -joliet -rock \
            /tmp/user-data /tmp/meta-data
        rm /tmp/user-data /tmp/meta-data
        echo \"✓ Seed ISO: \$(du -h '$ISO_PATH/$SEED_FILENAME' | cut -f1)\"
    "
    echo ""

    echo "## Provisioning VM from ISO..."
    REMOTE_OUTPUT=$(ssh root@$PROXMOX_HOST 'bash -s --' \
        "--iso" "$ISO_FILENAME" \
        "--vmid" "$VM_ID" \
        "--seed" "$SEED_FILENAME" \
        < "$SCRIPT_DIR/on-proxmox-iso.sh" | tee /dev/tty)
fi

SSH_EXIT_CODE=${PIPESTATUS[0]}
[[ $SSH_EXIT_CODE -ne 0 ]] && { echo "✗ Remote script failed ($SSH_EXIT_CODE)"; exit $SSH_EXIT_CODE; }

# -- Extract IP --
VM_IP=$(echo "$REMOTE_OUTPUT" | grep "VM_IP:" | sed 's/.*VM_IP: //')
[[ -z "$VM_IP" ]] && { echo "✗ Could not find VM_IP in output"; exit 1; }
echo ""
echo "- VM_IP: $VM_IP"

# -- Wait for SSH --
echo ""
echo "## Waiting for SSH..."
MAX_ATTEMPTS=60  # 60 * 5s = 5 min max
for ATTEMPT in $(seq 1 $MAX_ATTEMPTS); do
    if ssh $SSH_OPTS daniel@${VM_IP} 'echo ok' > /dev/null 2>&1; then
        echo "✓ SSH up"
        break
    fi
    [[ $ATTEMPT -eq $MAX_ATTEMPTS ]] && { echo "✗ SSH never came up"; exit 1; }
    sleep 5
done

# -- Wait for cloud-init to finish (holds apt lock) --
echo ""
echo "## Waiting for cloud-init..."
ssh $SSH_OPTS daniel@${VM_IP} 'cloud-init status --wait' 2>/dev/null || true
echo "✓ Cloud-init done"

# -- Install desktop + RDP over SSH --
echo ""
echo "## Installing xfce4 + xrdp..."
ssh $SSH_OPTS daniel@${VM_IP} << 'EOF'
set -e
# Set password for RDP login (cloud image mode has no password set)
# Use pre-hashed password (same SHA-512 hash as on-proxmox-iso-seed.yaml/nix config)
echo 'daniel:$6$K9VVOhEK7yygNC1T$PIirqGGbEqN6T4foCBTabahTNZfR.PDGqJUpzfAsHUxKs3vcSrv4my55.7nhgo6EQXeSgL025IjUQS.0AkIL80' | sudo chpasswd -e
echo 'daniel ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/daniel > /dev/null
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xfce4 xrdp qemu-guest-agent
echo "startxfce4" > ~/.xsession
sudo systemctl enable --now xrdp
sudo ufw allow 3389/tcp 2>/dev/null || true
EOF
echo "✓ Desktop + RDP installed"

# -- Reboot to apply kernel/lib updates --
echo ""
echo "## Rebooting..."
ssh $SSH_OPTS daniel@${VM_IP} 'sudo reboot' 2>/dev/null || true
sleep 15
for i in $(seq 1 30); do
    if ssh $SSH_OPTS daniel@${VM_IP} 'echo ok' > /dev/null 2>&1; then
        echo "✓ Back up after reboot"
        break
    fi
    sleep 5
done

# -- Verify RDP --
echo ""
echo "## Verifying RDP..."
ssh $SSH_OPTS daniel@${VM_IP} << 'EOF'
echo "- xrdp: $(systemctl is-active xrdp)"
echo "- port: $(ss -tlnp | grep 3389 || echo '3389 not listening')"
echo "- OS:   $(grep PRETTY_NAME /etc/os-release | cut -d= -f2)"
EOF

echo ""
echo "## Done"
echo ""
echo "SSH:  ssh daniel@${VM_IP}"
echo "RDP:  ${VM_IP}:3389   (user: daniel)"
echo ""
# Generate .rdp file for one-click connection
RDP_FILE="$SCRIPT_DIR/connect-vm${VM_ID}-${VM_IP}.rdp"
cat > "$RDP_FILE" << EOF
full address:s:${VM_IP}
username:s:daniel
EOF
echo "macOS:  open $RDP_FILE"
echo ""
