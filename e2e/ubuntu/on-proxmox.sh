#!/bin/bash
# Runs on Proxmox host via: bash -s -- --iso <file> --vmid <id> < on-proxmox.sh

# VM defaults
CORES=4; MEMORY=8192; DISK_SIZE="64"
NETWORK="virtio,bridge=vmbr0,firewall=1"
STORAGE="local-zfs"; SCSIHW="virtio-scsi-single"
ISO_STORAGE="pve-storage_backups-isos"
ISO_PATH="/pve-storage/backups-isos/template/iso"
VM_NAME="ubuntu2404"

command -v jq >/dev/null || { echo "✗ jq not found"; exit 1; }

echo "## on-proxmox start: $(hostname) $(date -Iseconds)"

# -- Cleanup trap (runs on any exit) --
MOUNT_DIR=""
cleanup() {
    [[ -n "$MOUNT_DIR" && -d "$MOUNT_DIR" ]] && { umount "$MOUNT_DIR" 2>/dev/null || true; rmdir "$MOUNT_DIR" 2>/dev/null || true; }
    rm -f /tmp/ubuntu-vmlinuz /tmp/ubuntu-initrd
    [[ -n "${SEED_FILENAME:-}" ]] && rm -f "$ISO_PATH/$SEED_FILENAME"
}
trap cleanup EXIT

# -- Argument parsing --
while [[ $# -gt 0 ]]; do
    case $1 in
        --iso)   ISO_FILENAME="$2"; shift 2 ;;
        --vmid)  VM_ID="$2";           shift 2 ;;
        --seed)  SEED_FILENAME="$2"; shift 2 ;;
        *)       echo "✗ Unknown arg: $1"; exit 1 ;;
    esac
done
[[ -z "${ISO_FILENAME:-}" || -z "${VM_ID:-}" || -z "${SEED_FILENAME:-}" ]] && {
    echo "✗ Usage: --iso <file> --vmid <id> --seed <seed-iso>"; exit 1; }

echo "- ISO:  $ISO_FILENAME"
echo "- Seed: $SEED_FILENAME"
echo "- VM_ID: $VM_ID"

# -- Validate files --
[[ ! -f "$ISO_PATH/$ISO_FILENAME" ]] && { echo "✗ ISO not found: $ISO_PATH/$ISO_FILENAME"; exit 1; }
[[ ! -f "$ISO_PATH/$SEED_FILENAME" ]] && { echo "✗ Seed not found: $ISO_PATH/$SEED_FILENAME"; exit 1; }
echo "✓ ISO: $(du -h "$ISO_PATH/$ISO_FILENAME" | cut -f1)  SHA256: $(sha256sum "$ISO_PATH/$ISO_FILENAME" | awk '{print $1}')"

# -- Extract kernel+initrd for direct boot (bypasses GRUB, allows autoinstall cmdline) --
echo "- Extracting kernel/initrd from ISO..."
MOUNT_DIR=$(mktemp -d)
mount -o loop,ro "$ISO_PATH/$ISO_FILENAME" "$MOUNT_DIR"
cp "$MOUNT_DIR/casper/vmlinuz" /tmp/ubuntu-vmlinuz
cp "$MOUNT_DIR/casper/initrd" /tmp/ubuntu-initrd
umount "$MOUNT_DIR" && rmdir "$MOUNT_DIR"
MOUNT_DIR=""
echo "✓ Kernel/initrd extracted"

# -- Create VM --
if qm list | awk '$1 == '"$VM_ID"'' | grep -q .; then
    echo "✗ VM $VM_ID already exists — destroy it first: qm stop $VM_ID && qm destroy $VM_ID --purge"; exit 1
fi

qm create "$VM_ID" \
    --name "$VM_NAME" \
    --memory "$MEMORY" --cores "$CORES" \
    --net0 "$NETWORK" \
    --scsihw "$SCSIHW" \
    --scsi0 "$STORAGE:$DISK_SIZE" \
    --ide2 "$ISO_STORAGE:iso/$ISO_FILENAME,media=cdrom" \
    --ide0 "$ISO_STORAGE:iso/$SEED_FILENAME,media=cdrom" \
    --boot order=ide2\;scsi0\;net0 \
    --agent 1 --vga std \
    --args '-kernel /tmp/ubuntu-vmlinuz -initrd /tmp/ubuntu-initrd -append "autoinstall ds=nocloud;"'
echo "✓ VM $VM_ID created"

echo ""; qm config "$VM_ID"; echo ""

# -- Start --
qm start "$VM_ID"
for i in $(seq 1 30); do
    STATUS=$(qm status "$VM_ID" | awk '{print $2}')
    [[ "$STATUS" == "running" ]] && { echo "✓ VM running"; break; }
    sleep 2
done
[[ "$STATUS" != "running" ]] && { echo "✗ VM failed to start"; exit 1; }

# -- Wait for install to finish (VM powers off via autoinstall shutdown: poweroff) --
echo "- Waiting for installer to finish and power off..."
INSTALL_START=$SECONDS
for i in $(seq 1 90); do   # 90 * 10s = 15 min max
    sleep 10
    ELAPSED=$(( SECONDS - INSTALL_START ))
    STATUS=$(qm status "$VM_ID" | awk '{print $2}')
    if [[ "$STATUS" == "stopped" ]]; then
        echo "✓ Installer finished — VM powered off (${ELAPSED}s)"
        break
    fi
    echo "  - $i/90: waiting... ${ELAPSED}s ($STATUS)"
done
[[ "$STATUS" != "stopped" ]] && { echo "✗ VM never powered off (install failed or timed out)"; exit 1; }

# -- Reconfigure for disk boot and restart --
echo "- Reconfiguring for disk boot..."
qm set "$VM_ID" --delete args --delete ide0 --delete ide2
qm set "$VM_ID" --boot order=scsi0
rm -f "$ISO_PATH/$SEED_FILENAME"
echo "✓ Boot config updated"

echo "- Starting VM from disk..."
qm start "$VM_ID"

# -- Wait for guest-agent (proves OS booted from disk) --
echo "- Waiting for guest-agent..."
BOOT_START=$SECONDS
VM_IP=""
for i in $(seq 1 30); do   # 30 * 10s = 5 min max
    sleep 10
    ELAPSED=$(( SECONDS - BOOT_START ))
    VM_IP=$(qm guest cmd "$VM_ID" network-get-interfaces 2>/dev/null \
        | jq -r '[.[] | select(.name != "lo") | .["ip-addresses"][] | select(.["ip-address-type"] == "ipv4")] | first | .["ip-address"] // empty' 2>/dev/null || true)
    if [[ -n "$VM_IP" ]]; then
        echo "✓ VM booted from disk (${ELAPSED}s)"
        break
    fi
    echo "  - $i/30: waiting... ${ELAPSED}s"
done

[[ -z "$VM_IP" ]] && { echo "✗ VM failed to boot from disk"; exit 1; }
echo "- VM_IP: ${VM_IP}"
echo "✓ on-proxmox complete"
