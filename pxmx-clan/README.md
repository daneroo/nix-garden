# Clan garden

- <https://docs.clan.lol/getting-started/>

```bash
# on galois
nix shell git+https://git.clan.lol/clan/clan-core#clan-cli

clan --help
clan flakes create pxmx-clan
```

## Installer

I was able to re-use my own minimal installer (As root ssh login is allowed on it).

### Target disk

To identify the target disk I used `lsblk` on the installer.

```bash
ssh root@<IP> lsblk --output NAME,ID-LINK,FSTYPE,SIZE,MOUNTPOINT
# e.g.  
ssh root@192.168.2.124 lsblk --output NAME,ID-LINK,FSTYPE,SIZE,MOUNTPOINT
```

### Hardware config

```bash
clan machines update-hardware-config <machine_name> <hostname>

# OR

ssh root@<hostname> nixos-generate-config --no-filesystems --show-hardware-config > hardware-configuration.nix

ssh root@192.168.2.124 nixos-generate-config --no-filesystems --show-hardware-config > hardware-configuration.nix
```
