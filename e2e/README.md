# NixOS Installation End-to-End Testing

## Copied ISO digests (host)

- docker MacOS
a699ca2d73ba3e5fef29adb55fe479d74d0d8edfe9322c950ccb815389b3f7e9  nu-nixos-25.05.20250618.9ba04bd-aarch64-linux.iso - docker
1dc363d6bd2d79c12cc0c6c7e75357dddff7dc6e25e9bdca17bf9c760ecbc492  nu-nixos-25.05.20250618.9ba04bd-x86_64-linux.iso - docker

- nixos x86_64 - proxmox
d9e4e80b27f46ba153d5966f56b3fc982725712d4b308bbc829c449211890623  result/iso/nixos-25.05.20250618.9ba04bd-x86_64-linux.iso - native - 3min
1dc363d6bd2d79c12cc0c6c7e75357dddff7dc6e25e9bdca17bf9c760ecbc492  nu-nixos-25.05.20250618.9ba04bd-x86_64-linux.iso - docker

- nixos x86_64 - colima - incus (slow)
f19088a3dcc1fb7bc3b530b86738a9f3f220e136393eb7580b32d13ed13966b7  result/iso/nixos-25.05.20250618.9ba04bd-x86_64-linux.iso - incus

- nixos aarch64 - proxmox (slow)
c6e3d8cd7bb8c2d901794dfe0239975290a3e3f52867cf8e90b4fb53d8e1bed3  result/iso/nixos-25.05.20250618.9ba04bd-aarch64-linux.iso - native - 34min

- nixos arm64 - UTM
c6e3d8cd7bb8c2d901794dfe0239975290a3e3f52867cf8e90b4fb53d8e1bed3  result/iso/nixos-25.05.20250618.9ba04bd-aarch64-linux.iso - native
d9e4e80b27f46ba153d5966f56b3fc982725712d4b308bbc829c449211890623  result/iso/nixos-25.05.20250618.9ba04bd-x86_64-linux.iso - native cross-compile - 8min
a699ca2d73ba3e5fef29adb55fe479d74d0d8edfe9322c950ccb815389b3f7e9  nu-nixos-25.05.20250618.9ba04bd-aarch64-linux.iso - docker

## TODO

- [ ] remove all references to branch (after merge) feature/nixos-25-05-installer
- [ ] complete the proxmox-bootstrap script : validate what?
- [ ] find alternative so my installer can broadcast it;s ip!
  - [ ] nats, local or remote?
  - [ ] ntfy.sh
- [ ] try to build installer image in docker (both x86_64 and aarch64)
  - [ ] docker image: nixos/nix:latest multi-arch (x86_64 and aarch64)
  - [ ] docker image: nixos/nix:latest-arm64
  - [ ] docker image: nixos/nix:latest-amd64

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

## Discover installerIP: Publish and Subscribe

- Can use nats ()
- first idea: publish in loop from installer to ntfy.sh and subscribe on galois
- better idea (TODO): subscribe/respond to whatsmyip/discoverip/installer.ip on installer, publish/request ip on galois
- best idea: tur it into an elixir service, built with nix!

### NATS

```bash
# NATS subscribe - on galois
#server=demo.nats.io
#server=nats.ts.imetrical.com # installer not yet on ts!
server=gateway.imetrical.com
topic=im.qcic.installer.ip
nats sub -s $server $topic

# NATS publish - on nix installer (publish only once)
nix-shell -p natscli --run '
  #server=demo.nats.io
  #server=nats.ts.imetrical.com # installer not yet on ts!
  server=gateway.imetrical.com
  topic=im.qcic.installer.ip
  IF=$(ip -o -4 route show to default | awk "{print \$5}" | head -1)
  MAC=$(cat /sys/class/net/$IF/address)
  IP=$(ip -4 -o addr show dev $IF | cut -d" " -f7 | cut -d/ -f1)
  nats pub -s $server $topic "$MAC $IP"
'
```

### NTFY (curl and brew/ntfy)

```bash
# NTFY subscribe - on galois - curl:
topic=$(printf im.qcic | shasum -a 256 | awk '{print $1}'); curl -sN "https://ntfy.sh/$topic/sse" | sed -u -n 's/^data: //p'

# NTFY subscribe - on galois - ntfy sub:

brew install ntfy        # if you haven’t yet
topic=$(printf im.qcic | shasum -a 256 | awk '{print $1}')
ntfy sub "$topic"
ntfy sub "https://ntfy.sh/$topic"

# NTFY publish (once) - on installer with curl
t=$(printf im.qcic | sha256sum | awk '{print $1}'); IF=$(ip -o -4 route show to default | awk '{print $5;exit}'); MAC=$(cat /sys/class/net/$IF/address); IP=$(ip -4 -o addr show dev $IF | awk '{print $4}' | cut -d/ -f1); curl -sX POST "https://ntfy.sh/$t" -d "$MAC $IP"

# NTFY publish (once) - on installer with ntfy-sh package
nix-shell -p ntfy-sh --run 't=$(printf im.qcic | sha256sum | awk "{print \$1}"); IF=$(ip -o -4 route show to default | awk "{print \$5;exit}"); MAC=$(cat /sys/class/net/$IF/address); IP=$(ip -4 -o addr show dev $IF | awk "{print \$4}" | cut -d/ -f1); ntfy publish "https://ntfy.sh/$t" "$MAC $IP"'

# NTFY publish (loop) - on installer with elixir
# cheating a bit, but you see where this is going!!!
nix-shell -p elixir --run '
TOPIC=$(printf im.qcic | sha256sum | awk "{print \$1}")
IFACE=$(ip -o -4 route show to default | awk "{print \$5;exit}")
MAC=$(cat /sys/class/net/$IFACE/address)
IP=$(ip -4 -o addr show dev $IFACE | awk "{print \$4}" | cut -d/ -f1)
elixir -e '\''[t,mac,ip]=System.argv(); System.cmd("curl", ["-sX","POST","https://ntfy.sh/"<>t,"-d",mac<>" "<>ip])'\'' "$TOPIC" "$MAC" "$IP"
'
```

## Clan ISO password extraction

```bash
VMID=997
DUMP=/tmp/vm${VMID}.mem

echo "# 1. synchronous RAM dump (detach=false)"
( echo '{"execute":"qmp_capabilities"}'
  sleep 1
  echo '{"execute":"dump-guest-memory",'\
'"arguments":{"protocol":"file:'${DUMP//\//\\/}'",'\
'"paging":false,"detach":false}}'
) | socat - UNIX-CONNECT:/var/run/qemu-server/${VMID}.qmp >/dev/null

echo "# 2. wait until the dump file stops growing"
while :; do
  s1=$(stat -c%s "$DUMP"); sleep 0.5; s2=$(stat -c%s "$DUMP")
  [ "$s1" -eq "$s2" ] && break
done

echo "# 3. extract the password – no PCRE, no limits"
pw=$(strings -n 3 "$DUMP" \
     | grep -Eo '"pass"[[:space:]]*:[[:space:]]*"[a-z]+-[a-z]+-[a-z]+"' \
     | head -n1 | cut -d'"' -f4)

echo "root password: $pw"
rm -f "$DUMP"
```
