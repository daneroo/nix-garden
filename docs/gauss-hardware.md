# Gauss Hardware Baseline

`gauss` is an AZW Beelink SER8 planned as the second NixOS host, installed on
its internal NVMe. These observations were collected while the removable Fedora
test disk was booted, before the NixOS installation.

## Hardware

- Firmware: `SER8_P5C8V26`, dated 2024-05-23.
- CPU: AMD Ryzen 7 8845HS with Radeon 780M Graphics; 8 cores and 16 threads.
- RAM: 27 GiB.
- Internal NVMe: Crucial `CT1000P3PSSD8`, 931.5 GiB.
- External experiment disk: 1.8 TiB Sabrent USB disk.

## Storage Baseline

The Sabrent disk negotiated a 10 Gbps USB link on the SER8. Read-only
`hdparm -Tt` measurements from 2026-07-07 were:

- Sabrent USB disk: `436.04 MB/sec` buffered reads.
- Internal NVMe: `3820.29 MB/sec` buffered reads.

The same Sabrent disk measured roughly `312-323 MB/sec` on Hardy after its CPU
throttling fix, where the USB link was 5 Gbps. The SER8's baseline had healthy
`amd-pstate-epp` performance mode with boost enabled and no Intel thermal-clamp
equivalent.
