# NixOS First Steps

```bash
nix fmt flake.nix
nix flake update
```

## TODO: Merge 2025-07-14

- [ ] remove all references to branch (after merge) `feature/nixos-25-05-installer`
- [ ] make analogous script for colima/tart

These are experiments with Nix; on NixOS, Ubuntu and on MacOS

I am embarking on my Nix/NixOS journey, and I need to make a wholistic plan.
So far I have done learning experiments, enough to decide that this is the way forward for me.
I chose nix to eventually replace:

- My Homelab Infrastructure as Code
- My Homebrew Setup on MacOS (multiple systems)

This repository should contain:

- Phase 0: commit to repo layout from
  - [EmergentMind GitHub](https://github.com/EmergentMind/nix-config)
    - [Emergent Mind Blog](https://unmovedcentre.com/posts/)

- Phase 1: Bootstrapping processes (Determinate Systems installer)
  - Installing nix (on MacOS, Ubuntu, NixOS)
  - Minimal boot iso for NixOS - including (disko) disk formatting
  - one-liner to bootstrap on NixOS, Ubuntu, MacOS
- Phase 2: System Level: (multiple OSs/architectures/hosts)
  - MacOS System configs (nix-darwin)
  - NixOS System configs (NixOs)
  - updating, checking for updates and planning
- Phase 3: User Level: (multiple OSs/architectures/hosts)
  - home-manager
  - using secrets (age)
  - updating, checking for updates and planning
- Phase 4: Project Level: (multiple OSs/architectures/hosts)
  - (direnv, use flakes)
  - updating, checking for updates and planning

## MCP NixOS

- [mcp-nixos](https://mcp-nixos.io/)

## TODO

- [Colmena: for deployment](https://github.com/zhaofengli/colmena)
- [Clan.lol](https://clan.lol/)
- Explain the bootstrap process - and shorten it!
  - utimately - right from an off-the shelf installer (NixOS - Or ubuntu?)
  - or my minimal iso
  - or from a working NixOS
  - also combine everything into a safe architecture neutral script?
- Formatting best practices for Nix
  - formatter attribute/default values
  - invoke with `nix run nixpkgs#nixfmt-tree -- .`
  - or consider `shopt -s globstar`

## Tart

- cleanup: `~/.tart/`
- also runs MacOS
- <https://tart.run/quick-start/>
- [Tart Guest Agent](https://tart.run/blog/2025/06/01/bridging-the-gaps-with-the-tart-guest-agent/)
- <https://chatgpt.com/share/6856267e-df18-8013-8936-2eea85215ebc>

```bash
brew install cirruslabs/cli/tart          # CLI
brew install cirruslabs/cli/tart-guest-agent   # helper for clipboard & exec

tart create --linux --disk-size 64 nixos-vm
tart run --disk nu-nixos-25.05.20250618.9ba04bd-aarch64-linux.iso nixos-vm
# install guest agent, to get ip
tart ip nixos-vm
# regular format and install
tart run nixos-vm
```

## Colima

Ok, time to speed things up!

- MacOS
  - cleanup: `~/Library/Caches/colima`
  - Stéphane Graber / Zabbly
    - [Youtube Video: Running Incus on a Mac](https://www.youtube.com/watch?v=5tcpXcipQ9E&t=169s)
  - incus: running in ubuntu 24.04 VM - zfs root
  - got tailscale to work: expected
    - Container: NixOS 24.11 (incus cannot run nested vm's)
    - start: `incus launch images:nixos/24.11/arm64 nixos-container`
    - exec: `incus exec nixos-container bash`
    - got tailscale to work: unexpected!

```bash
brew install colima incus lima-additional-guestagents # additional if you want qemu/x86_64?

# aarch64
colima start --runtime incus --cpu 4 --memory 8 --vm-type vz
colima ssh cat /etc/lsb-release
incus launch images:nixos/25.05/arm64 nixos-vm --vm # NOT WORKING ON MacOS
incus launch images:nixos/25.05/arm64 nixos-container # WORKING

# x86_64
colima start --runtime incus --cpu 4 --memory 8 --vm-type vz --vz-rosetta -a x86_64
colima ssh cat /etc/lsb-release
incus launch images:nixos/25.05/amd64 nixos-container # WORKING
incus launch images:nixos/24.11/amd64 nixos-container # WORKING


incus exec nixos-container grep PRETTY /etc/os-release
incus exec nixos-container bash
nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#emacs-nox
export TERM=vt100
emacs /etc/nixos/configuration.nix
```

```nix
  nix.settings = {
    experimental-features = "nix-command flakes";
    sandbox = false;                     # Incus container lacks namespaces
  };
  virtualisation.docker.enable = true;
  # services.tailscale.enable = true;
  environment.systemPackages = [
    pkgs.emacs-nox
  ];
```

now rebuild

```bash
sudo nixos-rebuild switch \
  -I nixpkgs=https://github.com/NixOS/nixpkgs/archive/nixos-24.11.tar.gz \
  --option sandbox false
sudo nixos-rebuild switch --flake github:daneroo/nix-garden#minimal-amd64 --no-write-lock-file --option sandbox false

docker run hello-world
```

Cleanup

```bash
incus delete nixos-container # --force
colima stop
colima delete
colima prune --very-verbose
```

### Short-term 2024-11-19

- [ ] separate repo for clan, from galois to both proxmox (gauss) and UTM
- [ ] reproduce/cleanup documentation minimal-iso and install process

2024-02-18: I am able to run disko, but cannot perform a nix-install (disk config or boot is badly setup)

- [ ] NixOS: bootstrap from minimal iso
  - [x] test on proxmox (x86_64) - minimal-amd64
  - [x] test on UTM (aarch64) - minimal-arm64
- [ ] alternative (ZFS) disk layouts
- [ ] VSCode / remote development / Extensions
  - [ ] TODO alejandra for VSCode
- Phase 1: bootstrapping
  - [ ] NixOS
    - [ ] fix disko usage (zfs)
    - [ ] wrap install script in a flake
  - [ ] MacOS (UTM/MacOS and Proxmox/MacOS)
- Phases 2-4
  - [ ] nixos
  - [ ] nix-darwin
  - [ ] Home-manager
    - [ ] Consolidate `fleek-garden` repo.
  - [ ] direnv - CodeSpaces
    - [ ] Consolidate [`nixvana`](https://github.com/daneroo/nixvana) repo.

## Phase 1: Bootstrapping Nix

### MacOS

We will be using [Determinate Nix Installer](https://zero-to-nix.com/concepts/nix-installer) for MacOS (and perhaps Ubuntu, if we keep that)

### NixOS - OrbStack

```bash
nix fmt flake.nix
nix flake update

nixos-generate-config --no-filesystems --show-hardware-config

sudo sh -c 'nix shell nixpkgs#btrfs-progs -c \
  nixos-generate-config --show-hardware-config \
  > /etc/nixos/hardware-configuration.nix'

sudo nix --extra-experimental-features "nix-command flakes" \
  shell nixpkgs#btrfs-progs -c \
  nixos-generate-config --show-hardware-config |
sudo tee /etc/nixos/hardware-configuration.nix >/dev/null

# this is the old, non-experimental command – it just works
sudo nix-env -iA nixpkgs.btrfs-progs
```

### NixOS

## Updating Configuration (WIP)

```bash
git clone https://github.com/daneroo/nix-garden
cd nix-garden
# sudo nixos-rebuild switch --flake .#ARCH_TARGET --no-write-lock-file
sudo nixos-rebuild switch --flake ./#minimal-amd64 --no-write-lock-file
sudo nixos-rebuild switch --flake .#minimal-arm64 --no-write-lock-file

# or

nix flake show github:daneroo/nix-garden
sudo nixos-rebuild switch --flake github:daneroo/nix-garden#minimal-amd64 --no-write-lock-file
sudo nixos-rebuild switch --flake github:daneroo/nix-garden#minimal-arm64 --no-write-lock-file
```

## References

- Reference nix-config/dotfiles layouts
  - [EmergentMind GitHub](https://github.com/EmergentMind/nix-config)
    - [Emergent Mind Blog](https://unmovedcentre.com/posts/)
  - [Misterio77](https://github.com/Misterio77/nix-config)
- [Erase Your Darlings](https://grahamc.com/blog/erase-your-darlings/)
  - [Associated ZFS disko config](https://github.com/nix-community/disko-templates/blob/main/zfs-impermanence/disko-config.nix)
- Disko examples:
  - <https://github.com/nix-community/disko/tree/master/example>
  - <https://github.com/nix-community/disko-templates>
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
