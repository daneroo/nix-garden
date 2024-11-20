# Clan garden

- <https://docs.clan.lol/getting-started/>

## Notes

- [ ] The generated flake `my-clan`, or `pxmx-clan` must the root of it's own got repo.
- [ ] I seem to have to be on the same architecteure as the target system (x86_64)
- [x] My `own minimal-iso`  produces extraneous output when ssh'ing to execute commands.
- [ ] docker x86_64: seccomp stuff

## Create the new clan flake (directory/repo)

```bash
# on galois, in a new directory (will be it's own repo)
nix shell git+https://git.clan.lol/clan/clan-core#clan-cli

clan --help
clan flakes create nix-clan-garden
cd nix-clan-garden/
```

## Installer

No need to flash a USB disk.
I was able to re-use my own `minimal-iso` because root ssh login is allowed on it.

I did make the `/etc/profile` quiet for non terminal logins.

## Machine Configuration

- edit top level `flake.nix` and change `.descrtiption` and `.meta.name`

### Target disk for installation

- Boot up a new machine with my `minimal-iso` - 4Core/4GB.
- Validate host ssh: `ssh root@<IP>`
  - `ssh root@192.168.2.127`
  - `ssh root@192.168.2.127 'echo "validate clean output"'`
- Identify the target installation disk I used `lsblk` on the installer.
  - on proxmox: `scsi-0QEMU_QEMU_HARDDISK_drive-scsi0`
  - on UTM: no label!!!

To get the disk label (command):

```bash
ssh root@<IP> lsblk --output NAME,ID-LINK,FSTYPE,SIZE,MOUNTPOINT
# e.g.  (-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null)
ssh root@192.168.2.127 lsblk --output NAME,ID-LINK,FSTYPE,SIZE,MOUNTPOINT
ssh root@192.168.71.3 lsblk --output NAME,ID-LINK,FSTYPE,SIZE,MOUNTPOINT
```

### Replace configuration values

- Replace values in `machines/jon/configuration.nix`
  - users.users.user.username = "daniel";
  - clan.core.networking.targetHost = "root@192.168.2.127";
  - disko.devices.disk.main.device = "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0";
  - users.users.root.openssh.authorizedKeys.keys = `cat ~/.ssh/id_ed25519.pub`;
- Commit the changes (if necessary)

### Update Hardware config

**NOTE:** This seems to be broken, so use ssh for now.

Don't forget to commit, if not using `clan machined update-hardware-config`

```bash
# more verbose, but does not assume ssh keys already validated
ssh root@<hostname> nixos-generate-config --no-filesystems --show-hardware-config > machines/<machine_name>/hardware-configuration.nix

ssh root@192.168.2.127 nixos-generate-config --no-filesystems --show-hardware-config > machines/jon/hardware-configuration.nix

# OR

# this would be simpler, but requires ssh key to already ne validated
clan machines update-hardware-config <machine_name> <hostname>
clan machines update-hardware-config jon 192.168.2.127
```

### Check the flake

Seems to be broken (for now, on galois)

```bash
nix flake check
```

### Secrets

Create Your Admin Keypair:

- linux: `~/.config/sops/age/keys.txt`
- macos: `'/Users/daniel/Library/Application Support/sops/age/keys.txt'`

If you've already made one before, this step won't change or overwrite it.

```bash
clan secrets key generate
```

Add Your Public Key (to sops, this will be committed in repo)

The key was output in admin keypair generation, and is int the generated `keys.txt` file.

```bash
clan secrets users add $USER age1234abc...
```

## Deployment

```bash
clan machines install [MACHINE] --target-host <target_host>
clan machines install jon --target-host 192.168.2.127
```

## Docker

```bash
# aarch64
docker run -it --rm \
  -v $(pwd):/clan \
  -v "$HOME/Library/Application Support/sops/age/keys.txt:/root/.config/sops/age/keys.txt:ro" \
  -w /clan \
  nixpkgs/nix-flakes:nixos-24.05-aarch64-linux

# x86_64 : not working yet
# -security-opt seccomp=unconfined
# --privileged
docker run --platform linux/amd64 -it --rm \
  -v $(pwd):/clan \
  -v "$HOME/Library/Application Support/sops/age/keys.txt:/root/.config/sops/age/keys.txt:ro" \
  -w /clan \
  nixpkgs/nix-flakes:nixos-24.05-x86_64-linux

nix develop
# OR
nix shell git+https://git.clan.lol/clan/clan-core#clan-cli


clan secrets key show
```

## Lima VM

```bash
brew install lima

# Create a NixOS x86_64 VM specifically for clan
limactl start --name=test-x86 --arch=x86_64 default
```
