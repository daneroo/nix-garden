#!/bin/bash
# Runs on Proxmox via: cat on-proxmox-img.sh | ssh root@host 'bash -s --' ...
# Creates a VM from Ubuntu cloud image.

# -- Constants --------------------------------------------------------------

CORES=4
MEMORY=8192
DISK_SIZE_GB=64
NETWORK="virtio,bridge=vmbr0,firewall=1"
STORAGE="local-zfs"
SCSIHW="virtio-scsi-single"
ISO_PATH="/pve-storage/backups-isos/template/iso"
VM_NAME="ubuntu2404"
VM_USER="daniel"
SUBNET_PREFIX="192.168.2"
SSH_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrUdJY3Aj0Xi2zdlGrEHFv3FNnlMz6ASLclhhl9cj1p daniel@galois"

# -- Main -------------------------------------------------------------------

main() {
    parse_args "$@"
    echo "## on-proxmox-img start: $(hostname) $(date -Iseconds)"
    echo "- IMG:   $IMG_FILENAME"
    echo "- VM_ID: $VM_ID"

    assert_vm_absent
    validate_image
    create_vm
    import_disk
    configure_cloud_init
    echo ""; qm config "$VM_ID"; echo ""
    start_vm
    resolve_ip_via_ping_sweep

    echo "- VM_IP: ${VM_IP}"
    echo "✓ on-proxmox-img complete"
}

# -- CLI --------------------------------------------------------------------

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --img)   IMG_FILENAME="$2"; shift 2 ;;
            --vmid)  VM_ID="$2";        shift 2 ;;
            *)       echo "✗ Unknown arg: $1"; exit 1 ;;
        esac
    done
    [[ -z "${IMG_FILENAME:-}" || -z "${VM_ID:-}" ]] && {
        echo "✗ Usage: --img <file> --vmid <id>"; exit 1; }
}

# -- Steps ------------------------------------------------------------------

assert_vm_absent() {
    if qm list | awk '$1 == '"$VM_ID"'' | grep -q .; then
        echo "✗ VM $VM_ID already exists — destroy first: qm stop $VM_ID && qm destroy $VM_ID --purge"
        exit 1
    fi
}

validate_image() {
    [[ ! -f "$ISO_PATH/$IMG_FILENAME" ]] && {
        echo "✗ Image not found: $ISO_PATH/$IMG_FILENAME"; exit 1; }
    echo "✓ IMG: $(du -h "$ISO_PATH/$IMG_FILENAME" | cut -f1)"
}

create_vm() {
    qm create "$VM_ID" \
        --name "$VM_NAME" \
        --memory "$MEMORY" --cores "$CORES" \
        --machine q35 \
        --net0 "$NETWORK" \
        --scsihw "$SCSIHW" \
        --agent 1 \
        --serial0 socket --vga std
    echo "✓ VM $VM_ID created"
}

import_disk() {
    echo "- Importing cloud image..."
    qm set "$VM_ID" --scsi0 "$STORAGE:0,import-from=$ISO_PATH/$IMG_FILENAME"
    qm resize "$VM_ID" scsi0 "${DISK_SIZE_GB}G"
    echo "✓ Disk imported and resized to ${DISK_SIZE_GB}G"
}

configure_cloud_init() {
    echo "- Configuring cloud-init..."
    qm set "$VM_ID" --ide2 "$STORAGE:cloudinit"
    qm set "$VM_ID" --boot order=scsi0
    qm set "$VM_ID" --ciuser "$VM_USER"
    qm set "$VM_ID" --ipconfig0 ip=dhcp

    local keyfile
    keyfile=$(mktemp)
    echo "$SSH_PUBKEY" > "$keyfile"
    qm set "$VM_ID" --sshkeys "$keyfile"
    rm -f "$keyfile"
    echo "✓ Cloud-init configured"
}

start_vm() {
    echo "- Starting VM..."
    qm start "$VM_ID"
    local status
    for i in $(seq 1 30); do
        status=$(qm status "$VM_ID" | awk '{print $2}')
        [[ "$status" == "running" ]] && { echo "✓ VM running"; return; }
        sleep 2
    done
    echo "✗ VM failed to start"; exit 1
}

# Resolve VM IP from MAC address via ping sweep + ARP table.
# Cloud images don't have qemu-guest-agent pre-installed.
resolve_ip_via_ping_sweep() {
    local target_mac
    target_mac=$(qm config "$VM_ID" | grep "net0:" | sed -E 's/.*virtio=([^,]+).*/\1/')
    echo "## Resolving VM IP from MAC address..."
    echo "- TARGET_MAC: ${target_mac}"
    echo "- SUBNET_PREFIX: ${SUBNET_PREFIX}.0/24"

    ping_sweep() {
        {
            seq 1 254 | \
                xargs -P64 -I{} \
                    sh -c 'ping -c1 -W1 '"$SUBNET_PREFIX"'.{} >/dev/null 2>&1 || true'
        } || true
        echo "  ✓ Ping sweep completed"
        sleep 1
        VM_IP=$(ip neigh show | grep -i "${target_mac}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $1}')
    }

    echo "- Waiting for VM networking (20s)..."
    sleep 20

    VM_IP=""
    for try in 1 2 3; do
        sleep 10
        echo "- Ping sweep $try/3..."
        ping_sweep
        [[ -n "$VM_IP" ]] && return
    done

    echo "✗ Could not resolve VM IP after 3 attempts"; exit 1
}

main "$@"
