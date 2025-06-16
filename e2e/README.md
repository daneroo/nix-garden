# NixOS Installation End-to-End Testing

## TODO

- [ ] complete the proxmox-bootstrap script : validate what?
- [ ] find alternative so my installer can broadcast it;s ip!
  - [ ] nats, local or remote?
  - [ ] ntfy.sh
- [ ] try to build installer image in docker (both x86_64 and aarch64)
  - [ ] docker image: nixos/nix:latest multi-arch (x86_64 and aarch64)
  - [ ] docker image: nixos/nix:latest-arm64
  - [ ] docker image: nixos/nix:latest-amd64

```bash
# NATS
# on galois
$ nats sub -s demo.nats.io vm.boot
03:47:22 Subscribing on vm.boot
[#1] Received on "vm.boot"
fa:44:8c:d1:ae:32 192.168.2.155

# on nix installer
nix-shell -p natscli --run '
  IF=$(ip -o -4 route show to default | awk "{print \$5}" | head -1)
  MAC=$(cat /sys/class/net/$IF/address)
  IP=$(ip -4 -o addr show dev $IF | cut -d" " -f7 | cut -d/ -f1)
  nats pub -s demo.nats.io vm.boot "$MAC $IP"
'

# NTFY
# pure curl:
topic=$(printf qcic | shasum -a 256 | awk '{print $1}'); curl -sN "https://ntfy.sh/$topic/sse" | sed -u -n 's/^data: //p'
# or with brew:
brew install ntfy        # if you haven’t yet
topic=$(printf qcic | shasum -a 256 | awk '{print $1}')
ntfy sub "$topic"

# installer with curl
while true; do t=$(printf qcic | sha256sum | awk '{print $1}'); IF=$(ip -o -4 route show to default | awk '{print $5;exit}'); MAC=$(cat /sys/class/net/$IF/address); IP=$(ip -4 -o addr show dev $IF | awk '{print $4}' | cut -d/ -f1); curl -sX POST https://ntfy.sh/$t -d "$MAC $IP"; sleep 5; done

# with ntfy-sh package
nix-shell -p ntfy-sh --run 'while true; do t=$(printf qcic | sha256sum | awk "{print \$1}"); IF=$(ip -o -4 route show to default | awk "{print \$5;exit}"); MAC=$(cat /sys/class/net/$IF/address); IP=$(ip -4 -o addr show dev $IF | awk "{print \$4}" | cut -d/ -f1); ntfy publish "https://ntfy.sh/$t" "$MAC $IP"; sleep 5; done'

```

## Objectives

Test the complete NixOS installation process from ISO creation to system boot, focusing on:

- Automated testing of the new NixOS 25.05 installer framework
- x86_64/proxmox for now, aarch64/tart-vm later

Process:

- Create VM with iso already present,
- Boot from ISO,
- Recreate installer iso in installer - validate checksum
- Format disk and install NixOS, verify installation
- Recreate installer iso again - validate checksum
- Cleanup VM

## Requirements

- Minimize manual SSH interactions with Proxmox host
- Single SSH connection to copy and execute test script
- Configurable VM parameters (memory, disk size, cores)

## Invocation

```bash
# ssh-copy-id -i ~/.ssh/id_ed25519.pub root@hilbert
./proxmox-bootstrap.sh
# or from parent directory
./e2e/proxmox-bootstrap.sh
```

## Tasks

- [ ] make a simple script copy to host and execute - only echo parameters
- [ ] confirm iso is present, with sha256
- [ ] list vms
- [ ] find vm by id
- [ ] create vm if id does not exist