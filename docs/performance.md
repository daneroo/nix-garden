# Performance Notes

Context: these measurements came from `homelab-config-garden` before this repo became the source of truth.

## Storage

Old Fedora 43 COSMIC Atomic tests on `hardy` showed storage numbers were heavily affected by CPU throttling.

Before the throttling fix:

- Sabrent USB disk through a hub: `/dev/sda` buffered reads `87.78 MB/sec`.
- Internal NVMe during the same test: `/dev/nvme0n1` buffered reads `416.81 MB/sec`.
- Sabrent USB disk directly in left USB-C: `/dev/sda` buffered reads `62.36 MB/sec`.
- Internal NVMe during the same direct-USB test: `/dev/nvme0n1` buffered reads `342.31 MB/sec`.
- Sabrent USB link reported `speed=5000`.

After the throttling fix on 2026-07-08:

- Sabrent USB link still reported `speed=5000`.
- Sabrent USB disk buffered reads: `312.15 MB/sec`, then `322.55 MB/sec`.
- Internal NVMe buffered reads: `1399.55 MB/sec`, then `1386.54 MB/sec`.

Interpretation: the Sabrent disk is limited by the Chromebook's 5 Gbps USB link, but the earlier 62-88 MB/sec measurements were dominated by CPU/thermal throttling, not only USB link speed.

## Thermal Clamp

The bad state was not ordinary overheating:

- Temperatures were around 40C during the Fedora clamp observations.
- RAM had plenty available and swap was not in use.
- `intel_pstate max_perf_pct = 9`.
- `intel_powerclamp cur_state = 49/100`.
- `idle_inject/*` processes were visible with high CPU percentages.
- `tuned` high-performance mode did not clear the clamp.

The useful post-fix performance signal was CPU frequency recovering to about 3.9 GHz, with `scaling_max_freq = 4200000`.
