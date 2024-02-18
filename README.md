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

- [ ] bootstrap from minimal/full iso
- [ ] VSCode / remote development / Extensions

## Bootstrapping NixOS

### Full Install

- Boot with `nixos-gnome-23.11.4030.9f2ee8c91ac4-aarch64-linux.iso`
- Run the installation (formats disks, etc)

```bash
sudo nixos-rebuild switch --flake github:daneroo/nix-garden#nix-full --no-write-lock-file
```

### Minimal iso

- Boot with `nixos-minimal-23.11.4030.9f2ee8c91ac4-aarch64-linux.iso`
- .. pull a config with disko

```bash
nix-shell -p git
# clone this repo : NOT working!!!
git clone https://github.com/daneroo/nix-garden.git
```

## References

- [Youtube: Nerding out about Nix and NixOS with Jon Seager, Canonical](https://www.youtube.com/watch?v=9l-U2NwbKOc&t=1s)
  - [Jon Seager's nixos-config](https://github.com/jnsgruk/nixos-config)
    - disko
    - Borg backup
    - Hyprland Window Manager
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
