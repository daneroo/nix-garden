#!/bin/bash
# Runs on Proxmox via: { cat common.sh; cat img.sh; } | ssh root@host 'bash -s --' ...
# Requires: on-proxmox-common.sh prepended (provides constants + helpers)

# -- Guard: verify on-proxmox-common.sh was prepended ----------------------
# These variables must be provided by on-proxmox-common.sh (prepended via cat):
#   CORES, MEMORY, DISK_SIZE_GB  - VM hardware sizing
#   NETWORK, STORAGE, SCSIHW     - Proxmox storage/network config
#   ISO_STORAGE                  - Proxmox storage ID for ISO files (iso mode)
#   ISO_PATH                     - filesystem path to ISO/image directory
#   VM_NAME                      - VM display name in Proxmox
#   VM_USER                      - username for cloud-init and SSH access
#   SUBNET_PREFIX                - e.g. "192.168.2" for ping sweep IP resolution
#   SSH_PUBKEY                   - authorized SSH key for VM access
for var in CORES MEMORY DISK_SIZE_GB NETWORK STORAGE SCSIHW ISO_STORAGE ISO_PATH VM_NAME VM_USER SUBNET_PREFIX SSH_PUBKEY; do
    [[ -z "${!var:-}" ]] && { echo "✗ Missing $var — on-proxmox-common.sh not prepended?"; exit 1; }
done

# -- Main -------------------------------------------------------------------

main() {
    parse_args "$@"
    echo "## on-proxmox-img start: $(hostname) $(date -Iseconds)"
    echo "- IMG:   $IMG_FILENAME"
    echo "- VM_ID: $VM_ID"

    validate_image
    assert_vm_absent
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

validate_image() {
    [[ ! -f "$ISO_PATH/$IMG_FILENAME" ]] && {
        echo "✗ Image not found: $ISO_PATH/$IMG_FILENAME"; exit 1; }
    echo "✓ IMG: $(du -h "$ISO_PATH/$IMG_FILENAME" | cut -f1)"
}

create_vm() {
    qm create "$VM_ID" \
        --name "$VM_NAME" \
        --memory "$MEMORY" --cores "$CORES" \
        --net0 "$NETWORK" \
        --scsihw "$SCSIHW" \
        --agent 1 \
        --serial0 socket --vga serial0
    echo "✓ VM $VM_ID created"
}

import_disk() {
    echo "- Importing cloud image..."
    qm set "$VM_ID" --scsi0 "$STORAGE:0,import-from=$ISO_PATH/$IMG_FILENAME"
    qm resize "$VM_ID" scsi0 "${DISK_SIZE_GB}G"
    echo "✓ Disk imported and resized to ${DISK_SIZE_GB}G"
}

configure_cloud_init() {
    # Proxmox generates the seed ISO automatically from these settings
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

main "$@"
