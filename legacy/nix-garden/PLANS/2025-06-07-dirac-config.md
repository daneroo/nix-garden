# NixOS Plan for Dirac - Mac Mini (Late 2012)

## Host OS: NixOS

- System: Mac Mini (Late 2012)
- Specs: 16 GB RAM, single SSD
- Install: Full disk wipe, clean NixOS install
- Filesystem: Btrfs
  - Subvolume layout (e.g., @root, @home, @nixos, etc.)
  - zstd compression
  - Snapshots enabled
  - Future-proofing for multi-device (RAID1) setup

## Backup Strategy

- Tools: `borg` + `borgmatic`
- Snapshots: Pre-backup snapshots via `btrbk`
- Backups:
  - Deduplicated and compressed
  - Sent to NAS or remote target
  - Managed and pruned by `borgmatic`

## Snapshot Management

- Tool: `btrbk`
  - Periodic local snapshots
  - Configurable retention policies
  - Optional snapshot send/receive

## Containers & Virtual Machines

- Incus (successor to LXD)

  - System containers and VMs
  - Inner systems may run Docker
  - Shared Btrfs storage allows snapshots to be coordinated
  - Managed from outer NixOS host

## Optional Features

- Impermanence module (optional)
  - Declarative `/etc`, `/home`, etc.
  - Useful for rollback and reproducible state
- Networking: Tailscale (optional)
- Backup target: Synology NAS or other hosts

## Future Expansion

- Use ZFS for RAID1 on systems with 2+ SSDs
- Explore ZFS send/receive and dataset-based snapshots

## Benefits

- Full control and predictability (declarative NixOS)
- Smart local snapshots with low overhead (Btrfs)
- Offsite and deduplicated backups (Borg)
- NixOS host controls all aspects of the system, inner and outer
- Reproducible, rollback-ready, storage-efficient homelab base
