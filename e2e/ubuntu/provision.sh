#!/usr/bin/env bash
set -euo pipefail

# -- Constants --------------------------------------------------------------

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source shared constants (VM_USER, SSH_PUBKEY, ISO_PATH, etc.)
# Same file prepended to on-proxmox scripts — single source of truth
# shellcheck source=on-proxmox-common.sh
source "$SCRIPT_DIR/on-proxmox-common.sh"

readonly PROXMOX_HOST="hilbert"
readonly PASSWORD_HASH='$6$K9VVOhEK7yygNC1T$PIirqGGbEqN6T4foCBTabahTNZfR.PDGqJUpzfAsHUxKs3vcSrv4my55.7nhgo6EQXeSgL025IjUQS.0AkIL80'
readonly ISO_FILENAME="ubuntu-24.04.4-live-server-amd64.iso"
readonly IMG_FILENAME="noble-server-cloudimg-amd64.img"
readonly SEED_FILENAME="ubuntu-rdp-seed-$(date +%s).iso"  # ISO mode only
readonly SSH_OPTS="-o ConnectTimeout=20 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes -o PasswordAuthentication=no"
readonly RDP_PORT="3389"

# -- Defaults (overridable via CLI: --mode, --vmid, --wm, --help) ----------

VM_ID="996"
MODE="img"  # "img" = cloud image (fast), "iso" = installer (fallback)
WM="gnome"  # "gnome", "kde", "xfce", "none"

# -- Desktop config (resolved from WM by resolve_desktop) ------------------

DESKTOP_PACKAGES=""
DESKTOP_SESSION=""

# -- Shared state (set by provision_vm, read by post-provision steps) -------

REMOTE_OUTPUT=""
VM_IP=""

# -- Main ------------------------------------------------------------------

main() {
    parse_args "$@"
    print_banner
    provision_vm
    extract_ip
    wait_for_ssh
    wait_for_cloud_init
    configure_user
    if [[ "$WM" != "none" ]]; then
        install_desktop
        reboot_vm
        verify_rdp
    fi
    print_summary
}

# -- CLI --------------------------------------------------------------------

show_usage() {
    echo "Usage: $0 [--mode img|iso] [--wm gnome|kde|xfce|none] [--vmid <ID>]"
    echo ""
    echo "Options:"
    echo "  --mode, -m    Provisioning mode: img (cloud image) or iso (installer)"
    echo "                Default: img"
    echo "  --wm          Desktop environment: gnome, kde, xfce, none"
    echo "                Default: gnome"
    echo "  --vmid        Virtual Machine ID (integer). Default: 996"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                          # cloud image, GNOME, VM 996"
    echo "  $0 --wm xfce               # cloud image, xfce, VM 996"
    echo "  $0 --wm none               # cloud image, no desktop (SSH only)"
    echo "  $0 --mode iso --wm kde      # ISO installer, KDE, VM 996"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode|-m)
                MODE="$2"
                [[ "$MODE" != "img" && "$MODE" != "iso" ]] && {
                    echo "✗ Invalid mode: $MODE (must be img or iso)"; exit 1; }
                shift 2 ;;
            --wm)
                WM="$2"
                [[ ! "$WM" =~ ^(gnome|kde|xfce|none)$ ]] && {
                    echo "✗ Invalid wm: $WM (must be gnome, kde, xfce, or none)"; exit 1; }
                shift 2 ;;
            --vmid)
                VM_ID="$2"
                [[ ! "$VM_ID" =~ ^[0-9]+$ ]] && {
                    echo "✗ Invalid vmid: $VM_ID (must be integer)"; exit 1; }
                shift 2 ;;
            --help|-h)
                show_usage; exit 0 ;;
            *)
                echo "✗ Unknown option: $1"
                show_usage; exit 1 ;;
        esac
    done
    resolve_desktop
}

# -- Desktop resolution -----------------------------------------------------
# Maps --wm choice to packages and X11 session command.
# All desktops include xrdp (X11-only) and qemu-guest-agent.

resolve_desktop() {
    [[ "$WM" == "none" ]] && return

    local base="xrdp qemu-guest-agent"
    case $WM in
        gnome)
            DESKTOP_PACKAGES="$base ubuntu-desktop-minimal"
            DESKTOP_SESSION="gnome-session" ;;
        kde)
            DESKTOP_PACKAGES="$base kde-plasma-desktop"
            DESKTOP_SESSION="startplasma-x11" ;;
        xfce)
            DESKTOP_PACKAGES="$base xfce4"
            DESKTOP_SESSION="startxfce4" ;;
    esac
}

# -- Provision --------------------------------------------------------------
# The on-proxmox scripts run on Proxmox via SSH stdin piping:
#   { cat common.sh; cat img.sh; } | ssh root@host 'bash -s --' ...
# Common constants (VM sizing, paths, SSH key) are in on-proxmox-common.sh.
# Output is captured in REMOTE_OUTPUT (tee /dev/tty shows progress in
# real-time). Both scripts emit "- VM_IP: <addr>" which extract_ip() parses.

print_banner() {
    echo "# Ubuntu VM Provision"
    echo "- Host:  $PROXMOX_HOST"
    echo "- VM_ID: $VM_ID"
    echo "- User:  $VM_USER"
    echo "- Mode:  $MODE"
    echo "- WM:    $WM"
    echo ""
}

provision_vm() {
    if [[ "$MODE" == "img" ]]; then
        provision_cloud_image
    else
        provision_iso
    fi
}

provision_cloud_image() {
    echo "## Provisioning VM from cloud image..."
    # set -o pipefail ensures SSH failures propagate through the pipe to tee
    REMOTE_OUTPUT=$({ cat "$SCRIPT_DIR/on-proxmox-common.sh"
                      cat "$SCRIPT_DIR/on-proxmox-img.sh"
                    } | ssh root@$PROXMOX_HOST 'bash -s --' \
        "--img" "$IMG_FILENAME" \
        "--vmid" "$VM_ID" | tee /dev/tty) || {
        echo "✗ Remote script failed"; exit 1; }
}

provision_iso() {
    echo "- ISO:   $ISO_FILENAME"
    echo "- Seed:  $SEED_FILENAME"
    echo ""

    # Expand template variables (VM_USER, PASSWORD_HASH, SSH_PUBKEY) in seed YAML
    local seed_content
    seed_content=$(VM_USER="$VM_USER" PASSWORD_HASH="$PASSWORD_HASH" SSH_PUBKEY="$SSH_PUBKEY" \
        envsubst '${VM_USER} ${PASSWORD_HASH} ${SSH_PUBKEY}' < "$SCRIPT_DIR/on-proxmox-iso-seed.yaml")

    echo "## Building seed ISO on $PROXMOX_HOST..."
    ssh root@$PROXMOX_HOST "
        cat > /tmp/user-data << 'USERDATA'
${seed_content}
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
    REMOTE_OUTPUT=$({ cat "$SCRIPT_DIR/on-proxmox-common.sh"
                      cat "$SCRIPT_DIR/on-proxmox-iso.sh"
                    } | ssh root@$PROXMOX_HOST 'bash -s --' \
        "--iso" "$ISO_FILENAME" \
        "--vmid" "$VM_ID" \
        "--seed" "$SEED_FILENAME" | tee /dev/tty) || {
        echo "✗ Remote script failed"; exit 1; }
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
    echo "## Installing desktop ($WM)..."
    install_packages
    switch_to_networkmanager
    configure_xrdp_session
    configure_xrdp_service
    echo "✓ Desktop + RDP installed"
}

# Install desktop packages and start guest agent immediately.
install_packages() {
    ssh $SSH_OPTS ${VM_USER}@${VM_IP} << EOF
set -e
echo "- apt-get update (suppressing output)..."
sudo apt-get update -qq > /dev/null
echo "- apt-get upgrade (suppressing output)..."
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq > /dev/null
echo "- apt-get install ${DESKTOP_PACKAGES} (suppressing output)..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ${DESKTOP_PACKAGES} > /dev/null
sudo systemctl enable --now qemu-guest-agent
EOF
}

# Cloud images use systemd-networkd, but desktop packages pull in
# NetworkManager which takes over on reboot. Switch netplan renderer to
# NetworkManager (what Ubuntu Desktop uses). The IP will change once on
# reboot (different DHCP client-id); reboot_vm re-resolves via guest agent.
# Not applied until reboot (netplan apply would kill this SSH session).
switch_to_networkmanager() {
    echo "- Switching netplan to NetworkManager..."
    ssh $SSH_OPTS ${VM_USER}@${VM_IP} << 'EOF'
set -e
sudo install -m 600 /dev/null /etc/netplan/01-network-manager-all.yaml
sudo tee /etc/netplan/01-network-manager-all.yaml > /dev/null << 'NETPLAN'
network:
  version: 2
  renderer: NetworkManager
NETPLAN
sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg > /dev/null << 'CLOUDINIT'
network: {config: disabled}
CLOUDINIT
sudo rm -f /etc/netplan/50-cloud-init.yaml
sudo systemctl disable systemd-networkd 2>/dev/null || true
EOF
}

# Configure xrdp session files. GNOME needs environment variables to render
# properly (without these: black screen or broken wallpaper). Also disables
# Wayland in GDM (xrdp is X11-only) and suppresses polkit color-manager
# auth dialogs that appear over xrdp.
configure_xrdp_session() {
    echo "- Configuring xrdp session ($WM)..."
    ssh $SSH_OPTS ${VM_USER}@${VM_IP} << EOF
set -e
cat > ~/.xsessionrc << 'XSESSIONRC'
export GNOME_SHELL_SESSION_MODE=ubuntu
export XDG_CURRENT_DESKTOP=ubuntu:GNOME
export XDG_SESSION_DESKTOP=ubuntu-xorg
export XDG_CONFIG_DIRS=/etc/xdg/xdg-ubuntu:/etc/xdg
XSESSIONRC
echo "${DESKTOP_SESSION}" > ~/.xsession

if [ -f /etc/gdm3/custom.conf ]; then
    sudo sed -i 's/#\?WaylandEnable=.*/WaylandEnable=false/' /etc/gdm3/custom.conf
fi

sudo mkdir -p /etc/polkit-1/localauthority/50-local.d
sudo tee /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla > /dev/null << 'POLKIT'
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
POLKIT
EOF
}

# Enable xrdp service. Adds xrdp user to ssl-cert group so it can read
# its TLS key (Ubuntu 24.04 ships a symlink to the snakeoil cert).
configure_xrdp_service() {
    echo "- Enabling xrdp..."
    ssh $SSH_OPTS ${VM_USER}@${VM_IP} << EOF
set -e
sudo adduser xrdp ssl-cert
sudo systemctl enable --now xrdp
sudo ufw allow ${RDP_PORT}/tcp 2>/dev/null || true
EOF
}

reboot_vm() {
    echo ""
    echo "## Rebooting (previous IP: ${VM_IP})..."
    local old_ip="$VM_IP"
    timeout 30 ssh $SSH_OPTS ${VM_USER}@${VM_IP} 'sudo reboot' 2>/dev/null || true
    echo "- Waiting 15s for reboot..."
    sleep 15

    # The NetworkManager switch changes the DHCP client-id, so the IP may
    # change on this reboot. Query guest agent (installed in DESKTOP_PACKAGES)
    # to find the new IP.
    for i in $(seq 1 40); do
        # Guest agent first (fast, finds new IP if it changed)
        local new_ip
        new_ip=$(ssh -o ConnectTimeout=5 root@${PROXMOX_HOST} \
            "qm guest cmd ${VM_ID} network-get-interfaces 2>/dev/null" 2>/dev/null \
            | grep -o '"ip-address" : "[0-9.]*"' | grep -v 127.0.0.1 \
            | head -1 | grep -o '[0-9.]*' || true)
        if [[ -n "$new_ip" ]]; then
            [[ "$new_ip" != "$old_ip" ]] && echo "  ⚠ VM_IP changed: ${old_ip} → ${new_ip}"
            VM_IP="$new_ip"
            echo "  - $i/40: guest-agent → ${VM_IP}, trying SSH..."
            if timeout 5 ssh $SSH_OPTS ${VM_USER}@${VM_IP} 'echo ok' > /dev/null 2>&1; then
                echo "✓ Back up after reboot (${VM_IP})"
                return
            fi
        else
            echo "  - $i/40: guest-agent not ready, trying ${old_ip}..."
            # Fallback: try old IP (guest agent may not be up yet)
            if timeout 5 ssh $SSH_OPTS ${VM_USER}@${old_ip} 'echo ok' > /dev/null 2>&1; then
                echo "✓ Back up after reboot (${old_ip})"
                return
            fi
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
    echo ""
    echo "## Done"
    echo ""
    echo "SSH:    ssh ${VM_USER}@${VM_IP}"

    if [[ "$WM" != "none" ]]; then
        local rdp_file="$SCRIPT_DIR/connect-vm${VM_ID}-${VM_IP}.rdp"
        cat > "$rdp_file" << EOF
full address:s:${VM_IP}
username:s:${VM_USER}
EOF
        echo "RDP:    ${VM_IP}:${RDP_PORT}  (user: ${VM_USER})"
        echo "macOS:  open $rdp_file"
    fi
    echo ""
}

main "$@"
