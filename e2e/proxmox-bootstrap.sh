#!/usr/bin/env bash
set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
PROXMOX_HOST="hilbert"
VMID="997"
ISO_FILENAME="my-nixos-25.05.20250605.4792576-x86_64-linux.iso"

# Execute local script on remote host with named parameters
ssh root@$PROXMOX_HOST 'bash -s --' "--iso" "$ISO_FILENAME" "--vmid" "$VMID" < "$SCRIPT_DIR/local-script-for-remote-execution.sh"

# Now let's resolve the IP from the mac address
echo "## Resolving VM IP from MAC address..."

TARGET_MAC="b2:ea:94:49:db:e4"   # lowercase, colon-separated
SUBNET_PREFIX="192.168.2"        # 192.168.2.0/24
CONCURRENCY=64                   # how many pings in parallel
PING_TIMEOUT=1                   # seconds to wait for each reply

# Resolve VM IP from MAC address using parallel pings
VM_IP=$(seq 1 254 | xargs -P${CONCURRENCY} -n1 -I{} sh -c 'ping -c1 -W${PING_TIMEOUT} ${SUBNET_PREFIX}.{} >/dev/null 2>&1' ; sleep 1; arp -an | grep -i "${TARGET_MAC}" | sed -E 's/.*\(([0-9.]+)\).*/\1/')
echo "Found VM IP: ${VM_IP}"

# on proxmox side
#  ip neigh show | grep -i "$(echo 'B2:EA:94:49:DB:E4' | tr '[:upper:]' '[:lower:]')"
