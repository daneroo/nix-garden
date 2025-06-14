#!/bin/bash

echo "=== Remote Script Execution ==="
echo "Host: $(hostname)"
echo "Date: $(date)"
echo ""

# Initialize variables
ISO_IMAGE_FILE=""
VMID=""

# Function to show usage
show_usage() {
    echo "Usage: $0 --iso <ISO_FILE> --vmid <VM_ID>"
    echo "Options:"
    echo "  --iso, --iso-file    Path to ISO file (required)"
    echo "  --vmid, --vm-id      Virtual Machine ID - must be integer (required)"
    echo "  --help, -h           Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --iso /path/to/file.iso --vmid 123"
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

echo "Arguments received:"
echo "  ISO_IMAGE_FILE: $ISO_IMAGE_FILE"
echo "  VMID: $VMID"
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
if [ ! -f "$ISO_IMAGE_FILE" ]; then
    echo "✗ ERROR: ISO file does not exist: $ISO_IMAGE_FILE"
    exit 1
fi

# Check file extension (optional but good practice)
if [[ ! "$ISO_IMAGE_FILE" =~ \.(iso|ISO)$ ]]; then
    echo "⚠ WARNING: File doesn't have .iso extension: $ISO_IMAGE_FILE"
fi

echo "✓ ISO file exists: $ISO_IMAGE_FILE"

# Print file info and SHA256 sum
echo "File size: $(du -h "$ISO_IMAGE_FILE" | cut -f1)"
echo "Computing SHA256 sum..."
sha256sum "$ISO_IMAGE_FILE"
echo ""

# Check if VMID already exists (Proxmox VE)
if command -v qm >/dev/null 2>&1; then
    if qm list | grep -q "^[[:space:]]*$VMID[[:space:]]"; then
        echo "⚠ WARNING: VM with ID $VMID already exists!"
        echo "Existing VM details:"
        qm list | grep "^[[:space:]]*$VMID[[:space:]]"
    else
        echo "✓ VM ID $VMID is available"
    fi
else
    echo "⚠ WARNING: 'qm' command not found - cannot check VM existence"
fi

echo ""
echo "=== Script completed successfully ==="