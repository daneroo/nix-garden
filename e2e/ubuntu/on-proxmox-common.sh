#!/bin/bash
# Shared constants and helpers for on-proxmox-{img,iso}.sh
# Prepended via: { cat common.sh; cat img.sh; } | ssh root@host 'bash -s --' ...

# -- VM defaults ------------------------------------------------------------

CORES=4
MEMORY=8192
DISK_SIZE_GB=64
NETWORK="virtio,bridge=vmbr0,firewall=1"
STORAGE="local-zfs"
SCSIHW="virtio-scsi-single"
ISO_STORAGE="pve-storage_backups-isos"
ISO_PATH="/pve-storage/backups-isos/template/iso"
VM_NAME="ubuntu2404"
VM_USER="daniel"
SUBNET_PREFIX="192.168.2"
SSH_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrUdJY3Aj0Xi2zdlGrEHFv3FNnlMz6ASLclhhl9cj1p daniel@galois"

# -- Shared helpers ---------------------------------------------------------

# Check if VM already exists (fatal)
assert_vm_absent() {
    if qm list | awk '$1 == '"$VM_ID"'' | grep -q .; then
        echo "✗ VM $VM_ID already exists — destroy first: qm stop $VM_ID && qm destroy $VM_ID --purge"
        exit 1
    fi
}

# Start VM and wait for "running" status
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

# Resolve VM IP from MAC address via ping sweep + ARP table
# Sets VM_IP. Requires SUBNET_PREFIX and VM_ID.
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

# -- Contract ---------------------------------------------------------------
# Each on-proxmox script must:
#   1. Parse its own CLI args (--img/--iso, --vmid, etc.)
#   2. Emit "- VM_IP: <addr>" on stdout (parsed by provision.sh extract_ip)
