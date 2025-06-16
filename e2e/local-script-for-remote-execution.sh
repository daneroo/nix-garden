#!/bin/bash

# Network Config MAC to IP : for ping scan 
SUBNET_PREFIX="192.168.2"        # 192.168.2.0/24
PING_TIMEOUT=1                   # seconds to wait for each reply

# VM Configuration
CORES=4
MEMORY=8192
DISK_SIZE="32"
NETWORK="virtio,bridge=vmbr0,firewall=1"
STORAGE="local-zfs"
SCSIHW="virtio-scsi-single"
IOTHREAD=1
# Proxmox storage mapping: pve-storage_backups-isos -> /pve-storage/backups-isos/template/
ISO_STORAGE="pve-storage_backups-isos"  # Used in qm create --ide2
ISO_PATH="/pve-storage/backups-isos/template/iso"  # Used for filesystem checks
VM_NAME="nix2505"

echo "## Remote Script Start (proxmox side)"
echo ""
echo "Host: $(hostname)"
echo "Date: $(date)"
echo ""

# Initialize variables
ISO_IMAGE_FILE=""
VMID=""

# Function to show usage
show_usage() {
    echo "Usage: $0 --iso <ISO_FILENAME> --vmid <VM_ID>"
    echo "Options:"
    echo "  --iso, --iso-file    ISO filename (required)"
    echo "  --vmid, --vm-id      Virtual Machine ID - must be integer (required)"
    echo "  --help, -h           Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --iso my-nixos-25.05.20250605.4792576-x86_64-linux.iso --vmid 123"
}

# Function to validate integer
is_integer() {
    [[ $1 =~ ^[0-9]+$ ]]
}

# Function to validate VMID range (Proxmox typically uses 100-999999999)
is_valid_vmid() {
    local vmid=$1
    if ! is_integer "$vmid"; then
        return 1
    fi
    if [ "$vmid" -lt 100 ] || [ "$vmid" -gt 999999999 ]; then
        return 1
    fi
    return 0
}

# Parse arguments
if [ $# -eq 0 ]; then
    echo "✗ ERROR: No arguments provided"
    show_usage
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --iso|--iso-file)
            if [ -z "$2" ]; then
                echo "✗ ERROR: --iso requires a value"
                exit 1
            fi
            ISO_IMAGE_FILE="$2"
            shift 2
            ;;
        --vmid|--vm-id)
            if [ -z "$2" ]; then
                echo "✗ ERROR: --vmid requires a value"
                exit 1
            fi
            VMID="$2"
            shift 2
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "✗ ERROR: Unknown argument: $1"
            show_usage
            exit 1
            ;;
    esac
done

echo "## Arguments validation:"
echo ""
echo "  - ISO_IMAGE_FILE: $ISO_IMAGE_FILE"
echo "  - VMID: $VMID"
echo ""

# Validate required parameters
if [ -z "$ISO_IMAGE_FILE" ]; then
    echo "✗ ERROR: Missing required parameter --iso"
    show_usage
    exit 1
fi

if [ -z "$VMID" ]; then
    echo "✗ ERROR: Missing required parameter --vmid"
    show_usage
    exit 1
fi

# Validate VMID is a valid integer in acceptable range
if ! is_valid_vmid "$VMID"; then
    echo "✗ ERROR: VMID must be an integer between 100 and 999999999"
    echo "  Provided: '$VMID'"
    exit 1
fi

echo "✓ VMID validation passed: $VMID"

# Validate ISO file exists and has .iso extension
if [ ! -f "$ISO_PATH/$ISO_IMAGE_FILE" ]; then
    echo "✗ ERROR: ISO file does not exist: $ISO_PATH/$ISO_IMAGE_FILE"
    exit 1
fi

# Check file extension (optional but good practice)
if [[ ! "$ISO_IMAGE_FILE" =~ \.(iso|ISO)$ ]]; then
    echo "✗ ERROR: File doesn't have .iso extension: $ISO_IMAGE_FILE"
    exit 1
fi

echo "✓ ISO file exists in storage: $ISO_PATH/$ISO_IMAGE_FILE"

# Print file info and SHA256 sum
echo "  - File size: $(du -h "$ISO_PATH/$ISO_IMAGE_FILE" | cut -f1)"
echo "  - Computing SHA256 sum..."
sha256sum "$ISO_PATH/$ISO_IMAGE_FILE"
echo ""

# Create VM if VMID does not already exist (Proxmox VE)
if command -v qm >/dev/null 2>&1; then
    if qm list | grep -q "^[[:space:]]*$VMID[[:space:]]"; then
        echo "- INFO: VM with ID $VMID already exists!"
        echo "Existing VM details:"
        qm list | grep "^[[:space:]]*$VMID[[:space:]]"
    else
        echo "✓ VM ID $VMID is available"
        # Create VM here
        qm create "$VMID" \
            --memory "$MEMORY" \
            --cores "$CORES" \
            --net0 "$NETWORK" \
            --scsihw "$SCSIHW" \
            --scsi0 "$STORAGE:$DISK_SIZE" \
            --ide2 "$ISO_STORAGE:iso/$ISO_IMAGE_FILE,media=cdrom" \
            --boot order=scsi0\;ide2\;net0 \
            --agent 1 \
            --name "$VM_NAME"
    fi
else
    echo "✗ ERROR: 'qm' command not found - cannot check VM existence"
    exit 1
fi

# Here the VM should exist
echo "## VM Configuration"
echo ""
qm config "$VMID"
echo ""

## Starting VM
echo "Starting VM $VMID..."
qm start "$VMID"

## Waiting for VM to be running
echo "Waiting for VM to be running..."
MAX_ATTEMPTS=30
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    STATUS=$(qm status "$VMID" | grep "status:" | cut -d' ' -f2)
    echo "  Status: $STATUS"
    if [ "$STATUS" = "running" ]; then
        echo "✓ VM is running"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "✗ ERROR: VM failed to start within timeout"
    exit 1
fi
echo ""

echo "## Resolving VM IP from MAC address..."
# Now let's resolve the IP from the mac address
# Hold your nose the only version of this that works (without qemu-agent)
# is ping scanning the whole subnet.


# Extract MAC from VM config
# e.g. net0: virtio=B2:EA:94:49:DB:E4,bridge=vmbr0,firewall=1
TARGET_MAC=$(qm config "$VMID" | grep "net0:" | sed -E 's/.*virtio=([^,]+).*/\1/')
echo "Target MAC: ${TARGET_MAC}"
echo "Subnet: ${SUBNET_PREFIX}.0/24"
echo "Ping timeout: ${PING_TIMEOUT}s"

# Step 1: Run parallel pings
# This spawns 254 background processes (one for each IP in 192.168.2.1-254)
# The & at the end of ping makes each ping run in the background
for i in $(seq 1 254); do
  ping -c1 -W${PING_TIMEOUT} ${SUBNET_PREFIX}.$i >/dev/null 2>&1 &
done
# wait for ALL background processes to complete
# || true needed because most pings will fail (timeout) since most IPs don't exist
# set -e (above)would make the script exit on these failures
wait || true
# Step 2: Wait for ARP responses
sleep 1
# Step 3: Get IP from ARP table
# can't use arp on proxmox - using ip neigh instead
# VM_IP=$(arp -an | grep -i "${TARGET_MAC}" | sed -E 's/.*\(([0-9.]+)\).*/\1/')
# ip neigh show returns both IPv4 and IPv6 addresses, we only want the IPv4 one
VM_IP=$(ip neigh show | grep -i "${TARGET_MAC}" | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | awk '{print $1}')
echo "Found VM IP: ${VM_IP}"


echo ""
echo "## Script completed successfully (proxmox side)"