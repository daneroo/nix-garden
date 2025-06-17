# NixOS First Steps

These are experiments with Nix; on NixOS, Ubuntu and on MacOS

I am embarking on my Mix/NixOS journey, and I need to make a wholistic plan.
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

## TODO

- [Colmena: for deployment](https://github.com/zhaofengli/colmena)
- Explain the bootstrap process - and shorten it!
  - utimately - right from an off-the shelf installer (NixOS - Or ubuntu?)
  - or my minimal iso
  - or from a working NixOS
  - also combine everything into a safe architecture neutral script?
- Formatting best practices for Nix
  - formatter attribute/default values
  - invoke with `nix run nixpkgs#nixfmt-tree -- .`
  - or consider `shopt -s globstar`

## Colima

Ok, time to speed things up!

- MacOS
  - incus: running in ubuntu 24.04 VM - zfs root
  - start: `colima start --runtime incus --vm-type vz`
  - exec: `colima ssh cat /etc/lsb-release`
  - got tailscale to work: expected
    - Container: NixOS 24.11 (incus cannot run nested vm's)
    - start: `incus launch images:nixos/24.11/arm64 nixos-container`
    - exec: `incus exec nixos-container bash`
    - got tailscale to work: unexpected!

```bash
colima start --runtime incus --vm-type vz --cpu 4 --memory 8192
incus launch images:nixos/24.11/arm64 nixos-vm --vm # NOT WORKING ON MacOS
incus launch images:nixos/24.11/arm64 nixos-container # WORKING
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
  - [ ] add guard to `disko-format-install` with gum jq (constrain to proper arch)
  - [ ] split disko and install scripts (add gum choices...)
  - [ ] boot with boot.initrd.systemd (see EmergentMind:hosts/grief kernelModules vs availableKernelModules)
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

#### Modernizing with NixOS 25.05 Installer Framework (In Progress)

We are transitioning from the legacy custom ISO approach to NixOS 25.05's new installer framework built on `nixos-generators` and `nixos-install-tools`.

#### New NixOS 25.05 Approach (Target)

Key Improvements:

- Unified Framework: Built on official `nixos-generators` integration  
- Enhanced Tool Collection: `nixos-install-tools` package bundles disko, parted, e2fsprogs, etc.
- Better Integration: Enhanced disko and nixos-anywhere support
- Modern Build Process: Uses `system.build.images` and new build commands

Planned Workflow:

```bash
# On a working NixOS, of the right architecture, build the installer image
git clone https://github.com/daneroo/nix-garden.git
cd nix-garden
# Build installer images (new approach - produces nixos-25.05.xxx-*.iso files)
# x86_64
nix build .#nixosConfigurations.installer-x86_64.config.system.build.images.iso-installer
# copy the artifact
cp result/iso/nixos-25.05.20250605.4792576-x86_64-linux.iso my-nixos-25.05.20250605.4792576-x86_64-linux.iso
# checksum
sha256sum my-nixos-25.05.20250605.4792576-x86_64-linux.iso
# copy to our registry!
chmod 644 my-nixos-25.05.20250605.4792576-x86_64-linux.iso
scp -p ./my-nixos-25.05.20250605.4792576-x86_64-linux.iso daniel@galois:Downloads/iso/

# aarch64
nix build .#nixosConfigurations.installer-aarch64.config.system.build.images.iso-installer
# copy the artifact
cp result/iso/nixos-25.05.20250605.4792576-aarch64-linux.iso my-nixos-25.05.20250605.4792576-aarch64-linux.iso
# checksum
sha256sum my-nixos-25.05.20250605.4792576-aarch64-linux.iso
chmod 644 my-nixos-25.05.20250605.4792576-aarch64-linux.iso
scp -p ./my-nixos-25.05.20250605.4792576-aarch64-linux.iso daniel@galois:Downloads/iso/

## Now boot these images on a new machine: 8GB if you want to build the iso in the installer!
```

Bootstrap Workflow:

```bash
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null nixos@192.168.{2|73}.xx

# List the targets!
nix flake show github:daneroo/nix-garden?dir=scripts/disko-format-install --all-systems
# force update the cache - if necessary (cache busting)
# nix flake update --flake github:daneroo/nix-garden?dir=scripts/disko-format-install
nix run github:daneroo/nix-garden?dir=scripts/disko-format-install minimal-arm64
nix run github:daneroo/nix-garden?dir=scripts/disko-format-install minimal-amd64

# or while I'm on the branch
# but that still won;t work because scripts/disko-format refers to main branch
DISKO_AUTO_CONFIRM=true nix run --impure github:daneroo/nix-garden/feature/nixos-25-05-installer?dir=scripts/disko-format-install minimal-amd64
# So...
# we'll duplicate it here
FLAKE_URI="github:daneroo/nix-garden/feature/nixos-25-05-installer"
nix flake show ${FLAKE_URI} --json | jq '.nixosConfigurations | keys'
TARGET_HOST="minimal-amd64"
FLAKE_OUTPUT_REF="${FLAKE_URI}#${TARGET_HOST}"
sudo nix run github:nix-community/disko -- --mode disko --flake ${FLAKE_OUTPUT_REF}
# Test if the configuration can be built (without installing)
nix build ${FLAKE_URI}#nixosConfigurations.minimal-amd64.config.system.build.toplevel --dry-run
sudo nixos-install --flake ${FLAKE_OUTPUT_REF} --no-root-passwd
sudo nixos-install --flake ${FLAKE_OUTPUT_REF} --no-root-passwd --verbose
```

Disko Integration:

Our own `./scripts/disko-format-install` script combines disko disk formatting and nixos-install into a single operation. The manual steps it performs are:

- Disko examples: <https://github.com/nix-community/disko/tree/master/example>

```bash
# Show the available configs in the flake (top of this repo) that we can use
nix flake show github:daneroo/nix-garden
# nix-shell -p jq # if not already installed
# nix flake update github:daneroo/nix-garden # if necessary (caching)
nix flake show github:daneroo/nix-garden --json | jq '.nixosConfigurations | keys'

# First: disko formats the disk (destructive operation)
sudo nix run github:nix-community/disko -- --mode disko --flake github:daneroo/nix-garden#minimal-arm64
sudo nix run github:nix-community/disko -- --mode disko --flake github:daneroo/nix-garden#minimal-amd64

# Then: nixos-install installs the system to the formatted disk
sudo nixos-install --flake github:daneroo/nix-garden#minimal-arm64 --no-root-passwd
sudo nixos-install --flake github:daneroo/nix-garden#minimal-amd64 --no-root-passwd
```

### Migration Notes - Legacy Custom Minimal ISO

Note: This section documents the legacy approach. The `minimal-iso/` directory will be removed once the NixOS 25.05 implementation is complete.

Note: see also [nix-generators (image builders)](https://github.com/nix-community/nixos-generators)

```bash
nix run github:nix-community/nixos-generators -- --help
```

This is how we built our own custom iso, it's purpose is to be able to boot and install on a new machine.
It is derived from the NixOS [cd-dvd/installation-cd-minimal.nix](https://github.com/NixOS/nixpkgs/blob/24.05/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix), and in addition:

The image are renamed with `my-` prefix but otherwise keep the name of the artifact from the derivation. i.e.

```bash
❯ (cd ~/Downloads/iso/; sha256sum my-nixos-24.05.20240531.63dacb4-*.iso)
e8c39ae1f8239220d0e1b7371bb421083bb24442991f620450632e6f045bd64b  my-nixos-24.05.20240531.63dacb4-aarch64-linux.iso
fd90bfe1c177c676bb9f1497b7face1324b918fa1d35c988f862166c7bde4d17  my-nixos-24.05.20240531.63dacb4-x86_64-linux.iso
```

- enable flakes
- enable ssh
- show ip on console (when logged in as a terminal ([ -t 1]))

```bash
cd minimal-iso
nix build .#nixosConfigurations.x86_64Iso.config.system.build.isoImage
# or
nix build .#nixosConfigurations.aarch64Iso.config.system.build.isoImage

# Actually I can even build without cloning (if the VM has enough memory i.e. 8GB (aarch64) / 16GB (x86_64))
nix build 'github:daneroo/nix-garden?dir=minimal-iso#nixosConfigurations.x86_64Iso.config.system.build.isoImage'
nix build 'github:daneroo/nix-garden?dir=minimal-iso#nixosConfigurations.aarch64Iso.config.system.build.isoImage'

ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null nixos@192.168.2.92
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null nixos@192.168.69.5
```

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
