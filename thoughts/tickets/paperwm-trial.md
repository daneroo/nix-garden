# PaperWM Trial

## Outcome

Get PaperWM usable on `gauss` quickly enough for Daniel to judge it through real
work. Decide whether to abandon or productionize it only after that use.

Shared rationale and the later Niri boundary are in
[scrolling-desktop](../design/scrolling-desktop.md).

## First Experiment

- Install and enable PaperWM declaratively on `gauss`.
- Keep `hardy` unchanged.
- Use PaperWM's defaults; do not design preferences or shared modules yet.
- Validate only enough existing desktop behavior to begin real use.
- Do not expand the VM E2E harness during the feasibility experiment.
- Recover by applying clean `main` or selecting the previous NixOS generation.

## Deferred Until After Use

- PaperWM preference design and declarative customization.
- Multi-host adoption and reusable configuration boundaries.
- Proportional automated regression coverage.
- Any Niri session implementation.
