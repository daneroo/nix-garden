# C436F Throttling

Context: `hardy` is an ASUS Chromebook Flip C436F / Google Helios with MrChromebox firmware and an Intel Core i5-10210U.

## Bluefin

The old `homelab-config-garden` notes say the CPU clamp was also present on the Bluefin internal NVMe install.

## Fedora 43 COSMIC Atomic

The old `homelab-config-garden` notes captured the severe failure mode on Fedora 43 COSMIC Atomic:

- `thermald` was enabled and active.
- `intel_powerclamp` was loaded.
- `intel_pstate/max_perf_pct` was observed at `38`, and earlier at `9`.
- CPU frequency was around 600 MHz, with lower lock behavior around 400-640 MHz also observed.
- `Processor` thermal cooling devices at `cur_state=3` held `scaling_max_freq` to 640 MHz.

The validated workaround state on Fedora was:

- `thermald` masked and inactive.
- `intel_powerclamp` not loaded.
- `intel_pstate/no_turbo = 0`.
- `intel_pstate/max_perf_pct = 100`.
- `intel_pstate/min_perf_pct = 100`.
- `Processor` cooling devices at `cur_state=0`.
- CPU `scaling_max_freq = 4200000`.
- CPU frequency observed around 3.9 GHz.

## NixOS 26.05

Observed on 2026-07-08:

- Host identity matches the old notes: DMI vendor `Google`, product `Helios`, version `rev3`.
- Firmware matches the old notes: MrChromebox-2509.4.
- `thermald.service` is not installed, enabled, or active.
- `intel_powerclamp` is loaded, but its cooling device reports `cur_state=0`.
- `intel_pstate/max_perf_pct = 100`.
- `intel_pstate/min_perf_pct = 9`.
- `intel_pstate/no_turbo = 0`.
- `Processor` cooling devices report `cur_state=0`.
- CPU `scaling_max_freq` equals hardware max: `4200000`.
- CPU frequency was observed around 3.4 GHz during the check.
- CPU/package temperatures were around 55C.

Conclusion: the old failure mode applies to this hardware, but it was not actively clamping this NixOS boot. Do not add `thermald` casually on this machine. If `thermald` is introduced later, revisit this note first.
