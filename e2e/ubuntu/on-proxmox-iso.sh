#!/bin/bash
# Runs on Proxmox via: { cat common.sh; cat iso.sh; } | ssh root@host 'bash -s --' ...
# Requires: on-proxmox-common.sh prepended (provides constants + helpers)

# -- Guard: verify common.sh was prepended ---------------------------------
for var in CORES MEMORY DISK_SIZE_GB NETWORK STORAGE SCSIHW ISO_STORAGE ISO_PATH VM_NAME SUBNET_PREFIX SSH_PUBKEY; do
    [[ -z "${!var:-}" ]] && { echo "✗ Missing $var — on-proxmox-common.sh not prepended?"; exit 1; }
done

# -- Main -------------------------------------------------------------------

main() {
    parse_args "$@"
    echo "## on-proxmox-iso start: $(hostname) $(date -Iseconds)"
    echo "- ISO:   $ISO_FILENAME"
    echo "- Seed:  $SEED_FILENAME"
    echo "- VM_ID: $VM_ID"

    command -v jq >/dev/null || { echo "✗ jq not found"; exit 1; }

    validate_files
    extract_kernel
    assert_vm_absent
    create_vm
    echo ""; qm config "$VM_ID"; echo ""
    start_vm
    wait_for_install
    reconfigure_for_disk_boot
    start_vm
    resolve_ip_via_guest_agent

    echo "- VM_IP: ${VM_IP}"
    echo "✓ on-proxmox-iso complete"
}

# -- Cleanup (runs on any exit) ---------------------------------------------

MOUNT_DIR=""
cleanup() {
    [[ -n "$MOUNT_DIR" && -d "$MOUNT_DIR" ]] && {
        umount "$MOUNT_DIR" 2>/dev/null || true
        rmdir "$MOUNT_DIR" 2>/dev/null || true
    }
    rm -f /tmp/ubuntu-vmlinuz /tmp/ubuntu-initrd
    [[ -n "${SEED_FILENAME:-}" ]] && rm -f "$ISO_PATH/$SEED_FILENAME"
}
trap cleanup EXIT

# -- CLI --------------------------------------------------------------------

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --iso)   ISO_FILENAME="$2"; shift 2 ;;
            --vmid)  VM_ID="$2";        shift 2 ;;
            --seed)  SEED_FILENAME="$2"; shift 2 ;;
            *)       echo "✗ Unknown arg: $1"; exit 1 ;;
        esac
    done
    [[ -z "${ISO_FILENAME:-}" || -z "${VM_ID:-}" || -z "${SEED_FILENAME:-}" ]] && {
        echo "✗ Usage: --iso <file> --vmid <id> --seed <seed-iso>"; exit 1; }
}

# -- Steps ------------------------------------------------------------------

validate_files() {
    [[ ! -f "$ISO_PATH/$ISO_FILENAME" ]] && {
        echo "✗ ISO not found: $ISO_PATH/$ISO_FILENAME"; exit 1; }
    [[ ! -f "$ISO_PATH/$SEED_FILENAME" ]] && {
        echo "✗ Seed not found: $ISO_PATH/$SEED_FILENAME"; exit 1; }
    echo "✓ ISO: $(du -h "$ISO_PATH/$ISO_FILENAME" | cut -f1)  SHA256: $(sha256sum "$ISO_PATH/$ISO_FILENAME" | awk '{print $1}')"
}

extract_kernel() {
    # Extract kernel+initrd for direct boot (bypasses GRUB, allows autoinstall cmdline)
    echo "- Extracting kernel/initrd from ISO..."
    MOUNT_DIR=$(mktemp -d)
    mount -o loop,ro "$ISO_PATH/$ISO_FILENAME" "$MOUNT_DIR"
    cp "$MOUNT_DIR/casper/vmlinuz" /tmp/ubuntu-vmlinuz
    cp "$MOUNT_DIR/casper/initrd" /tmp/ubuntu-initrd
    umount "$MOUNT_DIR" && rmdir "$MOUNT_DIR"
    MOUNT_DIR=""
    echo "✓ Kernel/initrd extracted"
}

create_vm() {
    qm create "$VM_ID" \
        --name "$VM_NAME" \
        --memory "$MEMORY" --cores "$CORES" \
        --net0 "$NETWORK" \
        --scsihw "$SCSIHW" \
        --scsi0 "$STORAGE:$DISK_SIZE_GB" \
        --ide2 "$ISO_STORAGE:iso/$ISO_FILENAME,media=cdrom" \
        --ide0 "$ISO_STORAGE:iso/$SEED_FILENAME,media=cdrom" \
        --boot order=ide2\;scsi0\;net0 \
        --agent 1 --vga std \
        --args '-kernel /tmp/ubuntu-vmlinuz -initrd /tmp/ubuntu-initrd -append "autoinstall ds=nocloud;"'
    echo "✓ VM $VM_ID created"
}

wait_for_install() {
    # VM powers off automatically via autoinstall "shutdown: poweroff"
    echo "- Waiting for installer to finish and power off..."
    local start=$SECONDS
    for i in $(seq 1 90); do   # 90 * 10s = 15 min max
        sleep 10
        local elapsed=$(( SECONDS - start ))
        local status
        status=$(qm status "$VM_ID" | awk '{print $2}')
        if [[ "$status" == "stopped" ]]; then
            echo "✓ Installer finished — VM powered off (${elapsed}s)"
            return
        fi
        echo "  - $i/90: waiting... ${elapsed}s ($status)"
    done
    echo "✗ VM never powered off (install failed or timed out)"; exit 1
}

reconfigure_for_disk_boot() {
    # Remove direct-kernel args and CDROMs so VM boots from installed disk
    echo "- Reconfiguring for disk boot..."
    qm set "$VM_ID" --delete args --delete ide0 --delete ide2
    qm set "$VM_ID" --boot order=scsi0
    rm -f "$ISO_PATH/$SEED_FILENAME"
    echo "✓ Boot config updated"
}

resolve_ip_via_guest_agent() {
    # ISO mode installs qemu-guest-agent, so we can query IP directly
    echo "- Waiting for guest-agent..."
    local start=$SECONDS
    VM_IP=""
    for i in $(seq 1 30); do   # 30 * 10s = 5 min max
        sleep 10
        local elapsed=$(( SECONDS - start ))
        VM_IP=$(qm guest cmd "$VM_ID" network-get-interfaces 2>/dev/null \
            | jq -r '[.[] | select(.name != "lo") | .["ip-addresses"][] | select(.["ip-address-type"] == "ipv4")] | first | .["ip-address"] // empty' 2>/dev/null || true)
        if [[ -n "$VM_IP" ]]; then
            echo "✓ VM booted from disk (${elapsed}s)"
            return
        fi
        echo "  - $i/30: waiting... ${elapsed}s"
    done
    echo "✗ VM failed to boot from disk"; exit 1
}

main "$@"
