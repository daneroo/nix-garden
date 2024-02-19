# NixOS First Steps

These are experiments with NixOS and NixPkgs on MacOS

This is a testing ground for a repo that will host NixOS flake based configs.

## Objectives

- Minimal Flake based config
- Associated bootstrap from fresh NixOS install - one liner!
- Stretch goals:
  - Injecting secrets (age?)
  - Disk formatting and partitioning (disko)

## TODO

2024-02-18: I am able to run disko, but cannot perform a nix-install (disk config or boot is badly setup)

- [ ] refactor nixos-anywhere into a new target (#proxmox)
  - [ ] follow jnsgruk directory structure - host/proxmox
    - [ ] refactor install-with-disko.sh
    - [ ] confirm working
  - [ ] needs a root passwd for root@proxmox
  - [ ] remove `nixos-anywhere/` from this repo
  - [ ] rebuild configuration back up to post-install content
- [ ] bootstrap from minimal/full iso
- [ ] VSCode / remote development / Extensions

## Bootstrapping NixOS

Using the configuration example from [nixos-anywhere-examples](https://github.com/nix-community/nixos-anywhere-examples/),
I managed to get a minimal install working.

- This decouples the disko config from what usually appears in `hardware-configuration.nix`, because
  disko will add all devices that have a EF02 partition to the list already

### NixOS Anywhere

- Start from a nix enabled source host (Full Install)
  - needs flake support

````bash
cd nixos-anywhere
nix flake lock
# nix run github:nix-community/nixos-anywhere -- --flake <path to configuration>#<configuration name> --vm-test
nix run github:nix-community/nixos-anywhere -- --flake .#hetzner-cloud --vm-test

### Full Install

- Boot with `nixos-gnome-23.11.4030.9f2ee8c91ac4-aarch64-linux.iso`
- Run the installation (formats disks, etc)

```bash
nix-shell -p emacs-nox
emacs /etc/nixos/configuration.nix
# enable sshd, flakes, add emacs-nox and git
sudo nixos-rebuild switch --flake github:daneroo/nix-garden#post --no-write-lock-file

# or
git clone https://github.com/daneroo/nix-garden
sudo nixos-rebuild switch --flake github:daneroo/nix-garden#post --no-write-lock-file
````

### Minimal iso

- Boot with `nixos-minimal-23.11.4030.9f2ee8c91ac4-aarch64-linux.iso`
- .. pull a config with disko

```bash
nix-shell -p curl wget emacs-nox git
# clone this repo : NOT working!!!
git clone https://github.com/daneroo/nix-garden
./scripts/install-with-disko.sh
# sudo nixos-generate-config --root /path/to/your/directory
```

## References

- [Talk: disko and nixos-anywhere](https://www.youtube.com/watch?v=U_UwzMhixr8)
- [Youtube: Nerding out about Nix and NixOS with Jon Seager, Canonical](https://www.youtube.com/watch?v=9l-U2NwbKOc&t=1s)
  - [Jon Seager's nixos-config](https://github.com/jnsgruk/nixos-config)
    - disko
    - Borg backup
    - Hyprland Window Manager
- [Zaney's Install Video](https://www.youtube.com/watch?v=ay0OcWWOm5k)
  - [Zaney's NixOS Config](https://gitlab.com/Zaney/zaneyos)
- [disko](https://github.com/nix-community/disko)
- NixOS Anywhere
  - [nixos-anywhere docs](https://nix-community.github.io/nixos-anywhere/)
  - [nixos-anywhere GitHub](https://github.com/nix-community/nixos-anywhere)
  - [nixos-anywhere-examples GitHub](https://github.com/nix-community/nixos-anywhere-examples)
  - [Numtide Blog](https://numtide.com/blog/)
- _Note:_ Still trying to embed obsidian links in Markdown
- See Obsidian notes for more details.
- [Obsidian Nix MOC](obsidian://open?vault=MainVault&file=Projects%2FHomelab%2FNix%20-%20MOC)
  - [NixOS Obsidian Note](obsidian://open?vault=MainVault&file=Projects%2FHomelab%2FNix%20-%20NixOS)
  - [Nix Fleek Obsidian Note](obsidian://open?vault=MainVault&file=Projects%2FHomelab%2FNix%20-%20Fleek)
    - see [fleek-garden repo](https://github.com/daneroo/fleek-garden) for nix home-manager configs created by [fleek](https://github.com/ublue-os/fleek).
