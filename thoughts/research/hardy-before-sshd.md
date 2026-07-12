# Hardy Host Audit

Generated: 2026-07-12T15:10:34-04:00

Review before committing; this report intentionally omits network addresses, keys, serial numbers, and environment variables.

## Identity

```text
     Static hostname: hardy
           Icon name: computer-laptop
             Chassis: laptop 💻
          Machine ID: 774bf2a7e1ff49d9b9ac59849fdefa6c
             Boot ID: 9ca0180aa28b4938b666f15629501673
    Operating System: NixOS 26.05 (Yarara)
         CPE OS Name: cpe:/o:nixos:nixos:26.05
      OS Support End: Thu 2026-12-31
OS Support Remaining: 5month 2w 5d
              Kernel: Linux 6.18.38
        Architecture: x86-64
     Hardware Vendor: Google
      Hardware Model: Helios
        Hardware SKU: sku1
    Hardware Version: rev3
    Firmware Version: MrChromebox-2509.4
       Firmware Date: Sun 2025-11-30
        Firmware Age: 7month 1w 4d
NixOS: 26.05.20260707.0ad6f47 (Yarara)
```

## Running System

```text
current: /nix/store/w81j3ix2yq6pcsr0qx4jlzhb21cdw7wd-nixos-system-hardy-26.05.20260707.0ad6f47
booted:  /nix/store/0f2yx650pbppyi9y13ac982ibsf6xfk5-nixos-system-hardy-26.05.20260707.0ad6f47
profile: /nix/store/w81j3ix2yq6pcsr0qx4jlzhb21cdw7wd-nixos-system-hardy-26.05.20260707.0ad6f47
```

## Generations

```text
error: opening lock file "/nix/var/nix/profiles/system.lock": Permission denied
```

## SSH

```text
enabled: not-found
active:  inactive
```

## Filesystems

```text
TARGET         SOURCE                     FSTYPE OPTIONS
/              /dev/nvme0n1p2             btrfs  rw,relatime,ssd,discard=async,space_cache=v2,subvolid=5,subvol=/
├─/boot        /dev/nvme0n1p1             vfat   rw,relatime,fmask=0077,dmask=0077,codepage=437,iocharset=iso8859-1,shortname=mixed,errors=remount-ro
├─/home        /dev/nvme0n1p2[/home]      btrfs  rw,relatime,ssd,discard=async,space_cache=v2,subvolid=256,subvol=/home
└─/nix         /dev/nvme0n1p2[/nix]       btrfs  rw,relatime,ssd,discard=async,space_cache=v2,subvolid=257,subvol=/nix
  └─/nix/store /dev/nvme0n1p2[/nix/store] btrfs  ro,nosuid,nodev,relatime,ssd,discard=async,space_cache=v2,subvolid=257,subvol=/nix
```

## Block Devices

```text
NAME          SIZE TYPE FSTYPE MOUNTPOINTS
nvme0n1     476.9G disk        
├─nvme0n1p1     1G part vfat   /boot
├─nvme0n1p2 467.1G part btrfs  /home
│                              /nix/store
│                              /nix
│                              /
└─nvme0n1p3   8.8G part swap   [SWAP]
```

## Repository

```text
root: /home/daniel/nix-hardy
branch: main
head: f0f88be404c742fb1b5e4da482d75c8e427e1a63
## main...origin/main
?? thoughts/research/hardy-before-sshd.md
origin	git@github.com:daneroo/nix-hardy.git (fetch)
origin	git@github.com:daneroo/nix-hardy.git (push)
f0f88be (HEAD -> main, origin/main, origin/HEAD) Guard migration from legacy test credentials
20f8669 Enable secure SSH and host auditing
8ce6067 Refine workflow guidance after review
27ce439 Capture homelab platform direction
8516003 Establish repository documentation workflow
```
