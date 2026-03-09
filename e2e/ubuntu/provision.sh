#!/usr/bin/env bash
set -euo pipefail

# Configuration
PROXMOX_HOST="hilbert"
VM_ID="996"
ISO_FILENAME="ubuntu-24.04.4-live-server-amd64.iso"
SEED_FILENAME="ubuntu-rdp-seed-$(date +%s).iso"   # built from user-data by this script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_OPTS="-o ConnectTimeout=20 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes -o PasswordAuthentication=no"
ISO_PATH="/pve-storage/backups-isos/template/iso"

echo "# Ubuntu RDP Provision"
echo "- Host:  $PROXMOX_HOST"
echo "- VM_ID:  $VM_ID"
echo "- ISO:   $ISO_FILENAME"
echo "- Seed:  $SEED_FILENAME"
echo ""

# -- Build seed ISO on Proxmox using genisoimage (already installed there) --
# Pipe user-data via SSH; meta-data can be empty but must exist for cloud-init
echo "## Building seed ISO on $PROXMOX_HOST..."
ssh root@$PROXMOX_HOST "
    cat > /tmp/user-data << 'USERDATA'
$(cat "$SCRIPT_DIR/user-data")
USERDATA
    echo '' > /tmp/meta-data
    genisoimage -output '$ISO_PATH/$SEED_FILENAME' \
        -volid cidata -joliet -rock \
        /tmp/user-data /tmp/meta-data
    rm /tmp/user-data /tmp/meta-data
    echo \"✓ Seed ISO: \$(du -h '$ISO_PATH/$SEED_FILENAME' | cut -f1)\"
"
echo ""

# -- Run proxmox-side script via SSH pipe --
echo "## Provisioning VM on Proxmox..."
REMOTE_OUTPUT=$(ssh root@$PROXMOX_HOST 'bash -s --' \
    "--iso" "$ISO_FILENAME" \
    "--vmid" "$VM_ID" \
    "--seed" "$SEED_FILENAME" \
    < "$SCRIPT_DIR/on-proxmox.sh" | tee /dev/tty)
SSH_EXIT_CODE=${PIPESTATUS[0]}
[[ $SSH_EXIT_CODE -ne 0 ]] && { echo "✗ Remote script failed ($SSH_EXIT_CODE)"; exit $SSH_EXIT_CODE; }

# -- Extract IP --
VM_IP=$(echo "$REMOTE_OUTPUT" | grep "VM_IP:" | sed 's/.*VM_IP: //')
[[ -z "$VM_IP" ]] && { echo "✗ Could not find VM_IP in output"; exit 1; }
echo ""
echo "- VM_IP: $VM_IP"

# -- Wait for Ubuntu autoinstall to finish and SSH to come up --
echo ""
echo "## Waiting for Ubuntu autoinstall + SSH (this takes a few minutes)..."
MAX_ATTEMPTS=150  # 150 * 10s = 25 min (autoinstall takes 10-20 min)
for ATTEMPT in $(seq 1 $MAX_ATTEMPTS); do
    echo "  - $ATTEMPT/$MAX_ATTEMPTS..."
    if ssh $SSH_OPTS daniel@${VM_IP} 'echo ok' > /dev/null 2>&1; then
        echo "✓ SSH up"
        break
    fi
    [[ $ATTEMPT -eq $MAX_ATTEMPTS ]] && { echo "✗ SSH never came up"; exit 1; }
    sleep 10
done

# -- Install desktop + RDP over SSH --
echo ""
echo "## Installing xfce4 + xrdp (this takes a few minutes)..."
ssh $SSH_OPTS daniel@${VM_IP} << 'EOF'
set -e
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y xfce4 xrdp
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
