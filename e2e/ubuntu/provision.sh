#!/usr/bin/env bash
set -euo pipefail

# -- Constants --------------------------------------------------------------

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROXMOX_HOST="hilbert"
readonly VM_USER="daniel"
readonly PASSWORD_HASH='$6$K9VVOhEK7yygNC1T$PIirqGGbEqN6T4foCBTabahTNZfR.PDGqJUpzfAsHUxKs3vcSrv4my55.7nhgo6EQXeSgL025IjUQS.0AkIL80'
readonly IMG_FILENAME="noble-server-cloudimg-amd64.img"
readonly SSH_OPTS="-o ConnectTimeout=20 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o BatchMode=yes -o PasswordAuthentication=no"
readonly RUSTDESK_DEB_URL="https://github.com/rustdesk/rustdesk/releases/download/1.3.9/rustdesk-1.3.9-x86_64.deb"
readonly RUSTDESK_PASSWORD="daniel123"

# -- Defaults ---------------------------------------------------------------

VM_ID="996"

# -- Shared state -----------------------------------------------------------

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
    install_desktop
    reboot_vm
    install_rustdesk
    verify_desktop
    print_summary
}

# -- CLI --------------------------------------------------------------------

show_usage() {
    echo "Usage: $0 [--vmid <ID>] [--help]"
    echo ""
    echo "Options:"
    echo "  --vmid        VM ID (integer). Default: 996"
    echo "  --help, -h    Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                  # VM 996"
    echo "  $0 --vmid 993       # VM 993"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --vmid)
                VM_ID="$2"
                [[ ! "$VM_ID" =~ ^[0-9]+$ ]] && { echo "✗ Invalid vmid: $VM_ID"; exit 1; }
                shift 2 ;;
            --help|-h)
                show_usage; exit 0 ;;
            *)
                echo "✗ Unknown option: $1"
                show_usage; exit 1 ;;
        esac
    done
}

# -- Provision --------------------------------------------------------------

print_banner() {
    echo "# Ubuntu VM Provision"
    echo "- Host:  $PROXMOX_HOST"
    echo "- VM_ID: $VM_ID"
    echo "- User:  $VM_USER"
    echo ""
}

provision_vm() {
    echo "## Provisioning VM from cloud image..."
    REMOTE_OUTPUT=$(cat "$SCRIPT_DIR/on-proxmox-img.sh" \
        | ssh root@$PROXMOX_HOST 'bash -s --' \
        "--img" "$IMG_FILENAME" \
        "--vmid" "$VM_ID" | tee /dev/tty) || {
        echo "✗ Remote script failed"; exit 1; }
}

# -- Post-provision ---------------------------------------------------------

extract_ip() {
    VM_IP=$(echo "$REMOTE_OUTPUT" | grep "VM_IP:" | sed 's/.*VM_IP: //')
    [[ -z "$VM_IP" ]] && { echo "✗ Could not find VM_IP in output"; exit 1; }
    echo ""
    echo "- VM_IP: $VM_IP"
}

wait_for_ssh() {
    echo ""
    echo "## Waiting for SSH..."
    local max=60
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

# -- Desktop ----------------------------------------------------------------

install_desktop() {
    echo ""
    echo "## Installing desktop (GNOME)..."
    install_packages
    switch_to_networkmanager
    configure_gdm_x11
    echo "✓ Desktop installed"
}

# RustDesk does not support the Wayland login screen (official docs:
# "Login screen using Wayland is not supported"). Force GDM to use X11.
# Without this, GDM defaults to Wayland on VMs with only a virtual GPU,
# and RustDesk cannot capture the login screen.
configure_gdm_x11() {
    echo "- Configuring GDM to use X11 (required by RustDesk)..."
    ssh $SSH_OPTS ${VM_USER}@${VM_IP} << 'EOF'
set -e
sudo sed -i 's/^#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf
echo "- GDM WaylandEnable: $(grep 'WaylandEnable' /etc/gdm3/custom.conf)"
EOF
}

install_packages() {
    ssh $SSH_OPTS ${VM_USER}@${VM_IP} << EOF
set -e
echo "- apt-get update..."
sudo apt-get update -qq > /dev/null
echo "- apt-get upgrade (output suppressed)..."
sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -qq > /dev/null
echo "- Installing qemu-guest-agent (output suppressed)..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq qemu-guest-agent > /dev/null
sudo systemctl start qemu-guest-agent
echo "- Installing ubuntu-desktop-minimal (output suppressed)..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ubuntu-desktop-minimal > /dev/null
EOF
}

# Cloud images use systemd-networkd; desktop pulls in NetworkManager.
# Switch netplan renderer to avoid conflict on reboot.
# IP may change after reboot (different DHCP client-id); reboot_vm re-resolves via guest agent.
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

reboot_vm() {
    echo ""
    echo "## Rebooting (previous IP: ${VM_IP})..."
    local old_ip="$VM_IP"
    timeout 30 ssh $SSH_OPTS ${VM_USER}@${VM_IP} 'sudo reboot' 2>/dev/null || true
    echo "- Waiting 15s for reboot..."
    sleep 15

    for i in $(seq 1 40); do
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
            if timeout 5 ssh $SSH_OPTS ${VM_USER}@${old_ip} 'echo ok' > /dev/null 2>&1; then
                echo "✓ Back up after reboot (${old_ip})"
                return
            fi
        fi
        sleep 5
    done
    echo "✗ VM never came back after reboot"; exit 1
}

# -- RustDesk ---------------------------------------------------------------

install_rustdesk() {
    echo ""
    echo "## Installing RustDesk..."
    ssh $SSH_OPTS ${VM_USER}@${VM_IP} << EOF
set -e

echo "- Downloading rustdesk.deb..."
wget -q "${RUSTDESK_DEB_URL}" -O /tmp/rustdesk.deb
echo "- Installing rustdesk.deb (official method: apt install -fy)..."
sudo apt install -fy /tmp/rustdesk.deb > /dev/null 2>&1
rm -f /tmp/rustdesk.deb
echo "- RustDesk installed: \$(rustdesk --version 2>/dev/null || echo unknown)"

# The service starts automatically on install. Give it time to initialize
# and create config files in /root/.config/rustdesk/ before we stop it.
echo "- Waiting 10s for RustDesk service to initialize..."
sleep 10
echo "- Service state: \$(systemctl is-active rustdesk)"

echo "- Stopping RustDesk to configure..."
sudo systemctl stop rustdesk
echo "- Service state after stop: \$(systemctl is-active rustdesk)"

# 1. Set password in root's config.
#    rustdesk --password writes to /root/.config/rustdesk/RustDesk.toml.
#    Prints "Connection refused" (no IPC socket) but still writes; exit code 0.
echo "- Setting password in root config..."
sudo rustdesk --password ${RUSTDESK_PASSWORD}
echo "- Verifying password in root config..."
sudo grep -q '^password = .\+' /root/.config/rustdesk/RustDesk.toml \
    && echo "  password: set" || { echo "  ✗ password NOT set in root config"; exit 1; }

# 2. Enable direct LAN connections (TCP 21118) in root's config.
#    rustdesk --option requires a running IPC socket, so we write directly.
echo "- Enabling direct-server in root config..."
sudo grep -q 'direct-server' /root/.config/rustdesk/RustDesk2.toml 2>/dev/null \
    || echo "direct-server = 'Y'" | sudo tee -a /root/.config/rustdesk/RustDesk2.toml > /dev/null
echo "- Verifying direct-server in root config..."
sudo grep -q 'direct-server' /root/.config/rustdesk/RustDesk2.toml \
    && echo "  direct-server: set" || { echo "  ✗ direct-server NOT set in root config"; exit 1; }

# 3. Copy root's config to gdm user.
#    Direct connections (TCP 21118) are served by a subprocess running as gdm,
#    which reads from /var/lib/gdm3/.config/rustdesk/ — a completely separate
#    config from root's. The root service does NOT propagate its config to gdm.
#    Copy both files so gdm has the password and direct-server option.
echo "- Copying config to gdm user (serves direct connections on TCP 21118)..."
sudo mkdir -p /var/lib/gdm3/.config/rustdesk
sudo cp /root/.config/rustdesk/RustDesk.toml /var/lib/gdm3/.config/rustdesk/RustDesk.toml
sudo cp /root/.config/rustdesk/RustDesk2.toml /var/lib/gdm3/.config/rustdesk/RustDesk2.toml
sudo chown gdm:gdm /var/lib/gdm3/.config/rustdesk/RustDesk*.toml
echo "- Verifying gdm config..."
sudo grep -q '^password = .\+' /var/lib/gdm3/.config/rustdesk/RustDesk.toml \
    && echo "  password: set" || { echo "  ✗ password NOT set in gdm config"; exit 1; }
sudo grep -q 'direct-server' /var/lib/gdm3/.config/rustdesk/RustDesk2.toml \
    && echo "  direct-server: set" || { echo "  ✗ direct-server NOT set in gdm config"; exit 1; }

echo "- Starting RustDesk..."
sudo systemctl start rustdesk
echo "- Service state: \$(systemctl is-active rustdesk)"
EOF
    echo "✓ RustDesk installed"
}

# -- Verify -----------------------------------------------------------------

verify_desktop() {
    echo ""
    echo "## Verifying desktop..."
    ssh $SSH_OPTS ${VM_USER}@${VM_IP} << 'EOF'
set -e
echo "- OS:       $(grep PRETTY_NAME /etc/os-release | cut -d= -f2)"
echo "- RustDesk: $(systemctl is-active rustdesk)"

# lsof is required: ss -tlnp misses IPv6-bound sockets like RustDesk's TCP 21118.
# Wait up to 30s — gdm subprocess needs time to initialize after service start.
echo "- Waiting for TCP 21118..."
for i in $(seq 1 10); do
    sudo lsof -i TCP:21118 -P -n 2>/dev/null | grep -q LISTEN && break
    sleep 3
done
if sudo lsof -i TCP:21118 -P -n 2>/dev/null | grep -q LISTEN; then
    echo "- TCP 21118: listening (direct connection ready)"
else
    echo "✗ TCP 21118: NOT listening — direct RustDesk connection will fail"
    exit 1
fi

# Verify password is set
pw=$(sudo cat /var/lib/gdm3/.config/rustdesk/RustDesk.toml 2>/dev/null | grep '^password' | cut -d= -f2 | tr -d " '")
if [[ -z "$pw" ]]; then
    echo "✗ RustDesk password not set"
    exit 1
fi
echo "- Password:  set"
EOF
}

# -- Summary ----------------------------------------------------------------

print_summary() {
    echo ""
    echo "## Done"
    echo ""
    echo "SSH:      ssh ${VM_USER}@${VM_IP}"
    echo "RustDesk: connect to ${VM_IP}  (password: ${RUSTDESK_PASSWORD})"
    echo "Destroy:  ssh root@${PROXMOX_HOST} 'qm stop ${VM_ID} && qm destroy ${VM_ID} --purge'"
    echo ""
}

main "$@"
