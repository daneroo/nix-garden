# hardy-hardware-notes — Keep or Consolidate Hardware Evidence

Decide the durable home and useful level of detail for the hardware-specific
material currently split between [performance.md](../../docs/performance.md) and
[throttling.md](../../docs/throttling.md).

## Context

The notes preserve observations from earlier operating-system experiments as
well as the current NixOS baseline. They contain useful evidence about severe
CPU clamping, thermal controls, storage measurements, and the risk of adding
`thermald`. Some measurements are historical rather than instructions for the
current configuration.

## Questions

- Are performance measurements and throttling diagnosis distinct durable topics,
  or would one `hardy` hardware/troubleshooting document be easier to maintain?
- Which earlier Bluefin and Fedora observations still help diagnose this
  machine, and which are merely experiment history recoverable from Git?
- Should durable docs state only the known failure mode, current baseline, and
  recovery procedure, with raw measurements moved to research notes?
- Is there enough validated NixOS behavior to turn any workaround into
  configuration, checks, or an operational runbook?
- What evidence should be retained before changing thermal-management packages
  or kernel behavior?

## Desired Outcome

- One obvious place to consult before changing thermal or performance settings.
- Clear separation between current facts, diagnostic guidance, and historical
  experiment records.
- No duplicated conclusions across durable documents.
- Preserve measurements that remain useful for recognizing regressions.
