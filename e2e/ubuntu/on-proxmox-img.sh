#!/bin/bash
# Runs on Proxmox host via: bash -s -- --img <file> --vmid <id> < on-proxmox-img.sh
# Reference: https://pve.proxmox.com/wiki/Cloud-Init_Support

# VM defaults
CORES=4; MEMORY=8192; DISK_SIZE="64G"
NETWORK="virtio,bridge=vmbr0,firewall=1"
STORAGE="local-zfs"; SCSIHW="virtio-scsi-single"
ISO_PATH="/pve-storage/backups-isos/template/iso"
VM_NAME="ubuntu2404"
SUBNET_PREFIX="192.168.2"
SSH_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrUdJY3Aj0Xi2zdlGrEHFv3FNnlMz6ASLclhhl9cj1p daniel@galois"

echo "## on-proxmox-img start: $(hostname) $(date -Iseconds)"

# -- Argument parsing --
while [[ $# -gt 0 ]]; do
    case $1 in
        --img)   IMG_FILENAME="$2"; shift 2 ;;
        --vmid)  VM_ID="$2";        shift 2 ;;
        *)       echo "✗ Unknown arg: $1"; exit 1 ;;
    esac
done
[[ -z "${IMG_FILENAME:-}" || -z "${VM_ID:-}" ]] && {
    echo "✗ Usage: --img <file> --vmid <id>"; exit 1; }

echo "- IMG:   $IMG_FILENAME"
echo "- VM_ID: $VM_ID"

# -- Validate file --
[[ ! -f "$ISO_PATH/$IMG_FILENAME" ]] && { echo "✗ Image not found: $ISO_PATH/$IMG_FILENAME"; exit 1; }
echo "✓ IMG: $(du -h "$ISO_PATH/$IMG_FILENAME" | cut -f1)"

# -- Create VM --
if qm list | awk '$1 == '"$VM_ID"'' | grep -q .; then
    echo "✗ VM $VM_ID already exists — destroy it first: qm stop $VM_ID && qm destroy $VM_ID --purge"; exit 1
fi

qm create "$VM_ID" \
    --name "$VM_NAME" \
    --memory "$MEMORY" --cores "$CORES" \
    --net0 "$NETWORK" \
    --scsihw "$SCSIHW" \
    --agent 1 \
    --serial0 socket --vga serial0

# -- Import cloud image as disk --
echo "- Importing cloud image..."
qm set "$VM_ID" --scsi0 "$STORAGE:0,import-from=$ISO_PATH/$IMG_FILENAME"
qm resize "$VM_ID" scsi0 "$DISK_SIZE"
echo "✓ Disk imported and resized to $DISK_SIZE"

# -- Cloud-init config (Proxmox generates seed ISO automatically) --
echo "- Configuring cloud-init..."
qm set "$VM_ID" --ide2 "$STORAGE:cloudinit"
qm set "$VM_ID" --boot order=scsi0
qm set "$VM_ID" --ciuser daniel
qm set "$VM_ID" --ipconfig0 ip=dhcp

KEYFILE=$(mktemp)
echo "$SSH_PUBKEY" > "$KEYFILE"
qm set "$VM_ID" --sshkeys "$KEYFILE"
rm -f "$KEYFILE"
echo "✓ Cloud-init configured"

echo ""; qm config "$VM_ID"; echo ""

# -- Start --
echo "- Starting VM..."
qm start "$VM_ID"
for i in $(seq 1 30); do
    STATUS=$(qm status "$VM_ID" | awk '{print $2}')
    [[ "$STATUS" == "running" ]] && { echo "✓ VM running"; break; }
    sleep 2
done
[[ "$STATUS" != "running" ]] && { echo "✗ VM failed to start"; exit 1; }

# -- Resolve IP from MAC via ping sweep (from provision-on-proxmox.sh) --
echo "## Resolving VM IP from MAC address..."
TARGET_MAC=$(qm config "$VM_ID" | grep "net0:" | sed -E 's/.*virtio=([^,]+).*/\1/')
echo "- TARGET_MAC: ${TARGET_MAC}"
echo "- SUBNET_PREFIX: ${SUBNET_PREFIX}.0/24"

ping_sweep() {
    CONCURRENCY=64
    WAIT_S=1

    {
      seq 1 254 | \
        xargs -P"$CONCURRENCY" -I{} \
          sh -c 'ping -c1 -W'"$WAIT_S"' '"$SUBNET_PREFIX"'.{} >/dev/null 2>&1 || true'
    } || true
    echo "  ✓ Ping Sweep Completed"
    echo "  - Waiting for ARP table to settle..."
    sleep 1
    echo "  ✓ ARP table settled"

    VM_IP=$(ip neigh show | grep -i "${TARGET_MAC}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $1}')
}

echo "- VM newly created, wait before first ping sweep (20s)"
sleep 20

for try in {1..3}; do
    sleep 10
    echo "- Starting Ping Sweep $try/3"
    ping_sweep
    [ ! -z "$VM_IP" ] && break
done

if [ -z "$VM_IP" ]; then
    echo "✗ Could not find VM IP after 3 attempts"
    exit 1
fi
echo "- VM_IP: ${VM_IP}"
echo "✓ on-proxmox-img complete"
