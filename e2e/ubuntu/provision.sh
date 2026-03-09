#!/usr/bin/env bash
set -euo pipefail

# -- Constants --------------------------------------------------------------

readonly PROXMOX_HOST="hilbert"
readonly VM_USER="daniel"
readonly PASSWORD_HASH='$6$K9VVOhEK7yygNC1T$PIirqGGbEqN6T4foCBTabahTNZfR.PDGqJUpzfAsHUxKs3vcSrv4my55.7nhgo6EQXeSgL025IjUQS.0AkIL80'
readonly ISO_FILENAME="ubuntu-24.04.4-live-server-amd64.iso"
readonly IMG_FILENAME="noble-server-cloudimg-amd64.img"
readonly SEED_FILENAME="ubuntu-rdp-seed-$(date +%s).iso"  # ISO mode only
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SSH_OPTS="-o ConnectTimeout=20 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes -o PasswordAuthentication=no"
readonly ISO_PATH="/pve-storage/backups-isos/template/iso"
readonly DESKTOP_PACKAGES="xfce4 xrdp qemu-guest-agent"
readonly DESKTOP_SESSION="startxfce4"
readonly RDP_PORT="3389"

# -- Defaults (overridable via CLI: --mode, --vmid, --help) -----------------

VM_ID="996"
MODE="img"  # "img" = cloud image (fast), "iso" = installer (fallback)

# -- Shared state (set by provision_vm, read by post-provision steps) -------

REMOTE_OUTPUT=""
VM_IP=""

# -- Main ------------------------------------------------------------------

main() {
    print_banner
    provision_vm
    extract_ip
    wait_for_ssh
    wait_for_cloud_init
    configure_user
    install_desktop
    reboot_vm
    verify_rdp
    print_summary
}

# -- Provision --------------------------------------------------------------
# The on-proxmox scripts (img/iso) run on Proxmox via SSH stdin piping.
# Their stdout is captured in REMOTE_OUTPUT (tee /dev/tty shows progress
# in real-time). Both scripts emit "VM_IP: <addr>" which extract_ip() parses.

print_banner() {
    echo "# Ubuntu RDP Provision"
    echo "- Host:  $PROXMOX_HOST"
    echo "- VM_ID: $VM_ID"
    echo "- Mode:  $MODE"
    echo ""
}

provision_vm() {
    if [[ "$MODE" == "img" ]]; then
        provision_cloud_image
    else
        provision_iso
    fi

    # PIPESTATUS[0] is the ssh exit code (not tee's) from the pipeline above
    local ssh_exit=${PIPESTATUS[0]}
    [[ $ssh_exit -ne 0 ]] && { echo "✗ Remote script failed ($ssh_exit)"; exit $ssh_exit; }
}

provision_cloud_image() {
    echo "## Provisioning VM from cloud image..."
    REMOTE_OUTPUT=$(ssh root@$PROXMOX_HOST 'bash -s --' \
        "--img" "$IMG_FILENAME" \
        "--vmid" "$VM_ID" \
        < "$SCRIPT_DIR/on-proxmox-img.sh" | tee /dev/tty)
}

provision_iso() {
    echo "- ISO:   $ISO_FILENAME"
    echo "- Seed:  $SEED_FILENAME"
    echo ""

    # Build cloud-init seed ISO on Proxmox from on-proxmox-iso-seed.yaml
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
}

# -- Post-provision ---------------------------------------------------------
# All steps below run from Mac, operating on the VM over SSH using VM_IP.

extract_ip() {
    # Parse "- VM_IP: x.x.x.x" from the on-proxmox script's captured output
    VM_IP=$(echo "$REMOTE_OUTPUT" | grep "VM_IP:" | sed 's/.*VM_IP: //')
    [[ -z "$VM_IP" ]] && { echo "✗ Could not find VM_IP in output"; exit 1; }
    echo ""
    echo "- VM_IP: $VM_IP"
}

wait_for_ssh() {
    echo ""
    echo "## Waiting for SSH..."
    local max=60  # 60 * 5s = 5 min
    for attempt in $(seq 1 $max); do
        if ssh $SSH_OPTS ${VM_USER}@${VM_IP} 'echo ok' > /dev/null 2>&1; then
            echo "✓ SSH up"
            return
        fi
        sleep 5
    done
    echo "✗ SSH never came up"; exit 1
}

wait_for_cloud_init() {
    echo ""
    echo "## Waiting for cloud-init..."
    ssh $SSH_OPTS ${VM_USER}@${VM_IP} 'cloud-init status --wait' 2>/dev/null || true
    echo "✓ Cloud-init done"
}

configure_user() {
    echo ""
    echo "## Configuring user ${VM_USER}..."
    ssh $SSH_OPTS ${VM_USER}@${VM_IP} << EOF
set -e
echo '${VM_USER}:${PASSWORD_HASH}' | sudo chpasswd -e
echo '${VM_USER} ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/${VM_USER} > /dev/null
EOF
    echo "✓ User configured"
}

install_desktop() {
    echo ""
    echo "## Installing ${DESKTOP_PACKAGES}..."
    ssh $SSH_OPTS ${VM_USER}@${VM_IP} << EOF
set -e
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ${DESKTOP_PACKAGES}
echo "${DESKTOP_SESSION}" > ~/.xsession
sudo systemctl enable --now xrdp
sudo ufw allow ${RDP_PORT}/tcp 2>/dev/null || true
EOF
    echo "✓ Desktop + RDP installed"
}

reboot_vm() {
    echo ""
    echo "## Rebooting..."
    ssh $SSH_OPTS ${VM_USER}@${VM_IP} 'sudo reboot' 2>/dev/null || true
    sleep 15
    for i in $(seq 1 30); do
        if ssh $SSH_OPTS ${VM_USER}@${VM_IP} 'echo ok' > /dev/null 2>&1; then
            echo "✓ Back up after reboot"
            return
        fi
        sleep 5
    done
    echo "✗ VM never came back after reboot"; exit 1
}

# -- Verify + Summary -------------------------------------------------------

verify_rdp() {
    echo ""
    echo "## Verifying RDP..."
    ssh $SSH_OPTS ${VM_USER}@${VM_IP} << EOF
echo "- xrdp: \$(systemctl is-active xrdp)"
echo "- port: \$(ss -tlnp | grep ${RDP_PORT} || echo '${RDP_PORT} not listening')"
echo "- OS:   \$(grep PRETTY_NAME /etc/os-release | cut -d= -f2)"
EOF
}

print_summary() {
    local rdp_file="$SCRIPT_DIR/connect-vm${VM_ID}-${VM_IP}.rdp"
    cat > "$rdp_file" << EOF
full address:s:${VM_IP}
username:s:${VM_USER}
EOF

    echo ""
    echo "## Done"
    echo ""
    echo "SSH:    ssh ${VM_USER}@${VM_IP}"
    echo "RDP:    ${VM_IP}:${RDP_PORT}  (user: ${VM_USER})"
    echo "macOS:  open $rdp_file"
    echo ""
}

main "$@"
