#!/usr/bin/env bash
set -euo pipefail

echo "# Script Start (provisioning side)"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Configuration
PROXMOX_HOST="hilbert"
VMID="997"
ISO_FILENAME="my-nixos-25.05.20250605.4792576-x86_64-linux.iso"

# Execute local script on remote host with named parameters
ssh root@$PROXMOX_HOST 'bash -s --' "--iso" "$ISO_FILENAME" "--vmid" "$VMID" < "$SCRIPT_DIR/local-script-for-remote-execution.sh"

echo "## Resolving VM IP from MAC address..."
# Now let's resolve the IP from the mac address
# Hold your nose the only version of this that works (without qemu-agent)
# is ping scanning the whole subnet.

# Get MAC from remote Proxmox host
TARGET_MAC=$(ssh root@$PROXMOX_HOST "qm config $VMID | grep 'net0:' | sed -E 's/.*virtio=([^,]+).*/\1/'")
echo "Target MAC: ${TARGET_MAC}"
SUBNET_PREFIX="192.168.2"        # 192.168.2.0/24
PING_TIMEOUT=1                   # seconds to wait for each reply

# Resolve VM IP from MAC address using parallel pings
# VM_IP=$(seq 1 254 | xargs -P${CONCURRENCY} -n1 -I{} sh -c 'ping -c1 -W${PING_TIMEOUT} ${SUBNET_PREFIX}.{} >/dev/null 2>&1' ; sleep 1; arp -an | grep -i "${TARGET_MAC}" | sed -E 's/.*\(([0-9.]+)\).*/\1/')
# echo "Found VM IP: ${VM_IP}"

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
VM_IP=$(arp -an | grep -i "${TARGET_MAC}" | sed -E 's/.*\(([0-9.]+)\).*/\1/')
echo "Found VM IP: ${VM_IP}"

echo "## Successfully completed (provisioning side)"
