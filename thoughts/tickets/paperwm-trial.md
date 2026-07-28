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

## Production Direction

- Install PaperWM and its toggle on both hosts.
- A fresh user profile starts with PaperWM enabled.
- An established profile retains the user's last enabled or disabled choice; Nix
  does not continuously enforce that choice.
- Expose the same system-owned toggle executable to both the shell and Vicinae
  through `bin` and `share/vicinae/scripts`. Removing its package must remove
  both surfaces without leaving an artifact in the user's home.
- Assess the existing E2E VM suite only after the feature lands on `main`.
