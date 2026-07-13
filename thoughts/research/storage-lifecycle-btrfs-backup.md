# Btrfs Snapshots and Backup Combos

Research note, 2026-07-12, supporting `storage-lifecycle` and
`backup-reconciliation`, with the VM/system-container specifics for
`incus-host`.

## Layout First

Snapshot practice is decided at `disko` time by subvolume layout. A layout that
has aged well:

- `@root` — the system root; snapshot for rollback, exclude from backup.
- `@home` — snapshot and back up.
- `@nix` — never snapshot, never back up; it is rebuildable by definition.
- `@log`, `@cache` (or a broader `@persist` if impermanence arrives) — snapshot
  rarely or never.
- `@snapshots` — keeps snapshot clutter out of the mounted tree.

Mount with `compress=zstd` and `noatime`. The subvolume boundaries are the
snapshot policy; getting them into disko makes the policy reproducible.

## Three Layers, Not One

Snapshots are not backups — same disk, same filesystem bugs, same fire. The
proven homelab combo is three distinct layers:

1. **Local snapshots** for oops-recovery and rollback: `btrbk`
   (`services.btrbk`) or `snapper` (`services.snapper`), both packaged as NixOS
   modules with declarative retention. btrbk is the better fit here because the
   same config that snapshots also _replicates_; snapper is more
   desktop-timeline oriented.
2. **Replication** via btrbk `btrfs send/receive` to a second disk or host —
   fast, incremental, preserves compression and reflinks, and gives instantly
   mountable history. `hardy` ⇄ `gauss` or a Proxmox VM with a btrfs volume both
   work as targets.
3. **Offsite** with restic (`services.restic.backups`) or borg
   (`services.borgbackup.jobs`). Restic recommended: backend flexibility (S3,
   B2, rest-server over Tailscale), and `restic check`/`restic snapshots` are
   clean observation commands for the reconciliation model. Borg's edge is
   single-repo dedup/compression; either is fine — pick one and drill restores.

**Consistency pattern for 2 and 3:** always back up from a read-only snapshot,
not the live tree (`btrfs subvolume snapshot -r`, back up the snapshot path,
delete). That yields crash-consistent backups without stopping services. It is
not application consistency: databases still deserve an app-level dump
(`pg_dump`, etc.) into a directory that layer 3 picks up.

Retention as desired state, e.g. btrbk `48h 14d 8w 6m` locally, longer on the
replica, restic `--keep` policy offsite. All three layers expose list/check
commands — which is exactly what a `backup-reconciliation` loop needs: desired
retention in the flake, observed snapshots via CLI, drift correction and
verification scheduled.

## Maintenance Btrfs Actually Needs

- `services.btrfs.autoScrub` (monthly) — the checksum payoff; without scrub,
  corruption is found at restore time.
- Watch `btrfs device stats` (a node-exporter/monitoring input later).
- Occasional filtered `balance` when allocation runs hot; not routine.
- Qgroups (quotas) carry real overhead with many snapshots — relevant because
  Incus uses them for instance quotas.

## VMs and System Containers on Btrfs

This is where the sharp edge lives.

- **System containers: btrfs is the best case.** Each Incus container is a
  subvolume; snapshot, copy, and cross-host `incus copy` are instant
  send/receive operations. A btrfs-backed Incus pool for containers is ideal.
- **VMs: CoW-on-CoW.** A VM disk image is one large randomly-rewritten file —
  the pathological btrfs workload; unbounded fragmentation. Incus mitigates by
  disabling copy-on-write (`nodatacow`) on VM block volumes, which silently
  trades away checksums and compression for those volumes (and enabling pool
  compression prevents the nodatacow mitigation — they are mutually exclusive).
  The Incus docs further advise setting a VM root's `size.state` to ~2× its size
  on btrfs so qgroup quotas survive full-image rewrites, and the storage-driver
  comparison is blunt that ZFS is the more reliable choice for VM-heavy pools.
- **Practical resolution: two pools.** Incus happily runs multiple storage pools
  — btrfs for containers (and the host filesystem), plus a ZFS or LVM-thin pool
  for VM volumes when VMs become more than experiments. Until then, a btrfs VM
  pool with the caveats understood is fine for disposable test VMs.
- **Incus-native lifecycle**, declarative-ish via profiles: per-instance
  `snapshots.schedule` and `snapshots.expiry` for retention, `incus export` for
  portable instance backups, `incus copy --refresh` for incremental DR to a
  second host. Prefer these over reaching into the pool's subvolumes by hand;
  Incus owns that state. VM snapshots are crash-consistent by default;
  `--stateful` (with `migration.stateful`) also captures RAM.

## Suggested First Drill

One afternoon, on `hardy`: btrbk snapshotting `@home` with a small retention
set; restic to a rest-server or B2 bucket from a read-only snapshot; then the
part everyone skips — restore a deleted file from each of the three layers and
time it. That converts `backup-reconciliation` from design into evidence.

## Sources

- [Incus documentation: btrfs driver](https://linuxcontainers.org/incus/docs/main/reference/storage_btrfs/)
- [Incus documentation: storage driver comparison](https://linuxcontainers.org/incus/docs/main/reference/storage_drivers/)
- [Incus forum: nodatacow vs compression on btrfs](https://discuss.linuxcontainers.org/t/nodatacow-on-btrfs-storage-breaks-compression/18224)
- [btrbk](https://github.com/digint/btrbk)
- [restic](https://restic.net/)
