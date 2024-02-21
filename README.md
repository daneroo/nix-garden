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

- [ ] bootstrap from minimal/full iso
  - [ ] refactor shared config between proxnix and macnix
- [ ] custom iso: <https://nixos.wiki/wiki/Creating_a_NixOS_live_CD>
  - [ ] make aarch64 minimal iso
  - [ ] rename isos for clarity
- [ ] copy/paste from terminals
- [ ] alternative disk layouts
- [ ] describe nix config hierarchy (jsngruk)
- [ ] VSCode / remote development / Extensions

## Bootstrapping NixOS

Using the configuration example from [nixos-anywhere-examples](https://github.com/nix-community/nixos-anywhere-examples/),
I managed to get a minimal install working.

This decouples the disko config from what usually appears in `hardware-configuration.nix`, because
disko will add all devices that have a EF02 partition to the list already

### Minimal iso

- Boot with either minimal iso
  - `nixos-minimal-23.11.4030.9f2ee8c91ac4-x86_64-linux.iso`
  - `nixos-minimal-23.11.4030.9f2ee8c91ac4-aarch64-linux.iso`

```bash
nix-shell -p git
# clone this repo : NOT working!!!
git clone https://github.com/daneroo/nix-garden
./scripts/install-with-disko.sh
# sudo nixos-generate-config --root /path/to/your/directory
```

### Custom iso

Build our own custom iso

- enable flakes
- enable ssh
- show ip on console

```bash
cd minimal-iso
nix build .#nixosConfigurations.x86_64Iso.config.system.build.isoImage
# or
nix build .#nixosConfigurations.aarch64Iso.config.system.build.isoImage
```

## Updating Configuration (WIP)

```bash
git clone https://github.com/daneroo/nix-garden
cd nix-garden
sudo nixos-rebuild switch --flake ./#TARGET --no-write-lock-file
# or
sudo nixos-rebuild switch --flake github:daneroo/nix-garden#TARGET --no-write-lock-file
# update the flake
nix flake update
# rebuild
sudo nixos-rebuild switch --flake github:daneroo/nix-garden#post --no-write-lock-file
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
- [Custom installer iso](https://nixos.wiki/wiki/Creating_a_NixOS_live_CD)
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
