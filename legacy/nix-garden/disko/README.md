# disko templates

These are from <https://github.com/nix-community/disko-templates/>

They should be imported from a NoxOS configuration flake, e.g.

```nix
# USAGE in your configuration.nix.
# Update devices to match your hardware.
# {
#  imports = [ ./disko-config.nix ];
#  disko.devices.disk.main.device = "/dev/sda";
# }
```

Tey were obtained this way:

```bash
cd single-disk-ext4/
nix flake init --template github:nix-community/disko-templates#single-disk-ext4
cd ../zfs-impermanence/
nix flake init --template github:nix-community/disko-templates#zfs-impermanence
```
