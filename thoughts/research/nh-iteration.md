# nh — Porcelain Worth Adopting

Research note, 2026-07-12, supporting `nh-iteration`. Question: is a wrapper
like `nh` real value, or indirection? Context: the native commands are
acknowledged-anachronistic, and the repo's `just plan`/`just apply` already
encodes "think once, not every loop".

## The Plumbing/Porcelain Frame

Git settled this argument: plumbing (`rev-parse`, `update-ref`) is for
understanding and scripts; porcelain (`git switch`) is what humans type.
`nixos-rebuild` is aging plumbing pretending to be porcelain — a large legacy
script (upstream is rewriting it as `nixos-rebuild-ng`), and even the flakes CLI
still hides behind `experimental-features`. The ecosystem's own polish efforts
(nh, nvd, nom, Lix, Determinate's distribution) all concede the point. Having
built the manual loop first, this repo has already paid the understanding cost —
adopting porcelain now is earned abstraction, exactly consistent with the
guardrails.

## What nh Actually Adds

`nh` (nix-community, viperML — same author as wrapper-manager):

- `nh os switch|boot|test` runs **build → nvd closure diff → confirmation →
  activate**: literally the `just plan`/`apply` loop, maintained by people who
  iterate on NixOS daily. `--dry` stops after the diff.
- Builds render through `nom` (nix-output-monitor): a readable build tree
  instead of scrolling noise — meaningfully better failure diagnosis.
- `nh clean` understands what `nix-collect-garbage -d` misses: user/Home Manager
  profiles, `result` gcroots, keep-N/keep-age policies.
- `nh search` — fast package search from the terminal.
- Declarative adoption: `programs.nh.enable`, `programs.nh.clean.automatic` (+
  schedule/args), and a default flake path — the whole tool arrives as three
  lines of host config, including scheduled GC, which is homelab disk hygiene
  solved declaratively.

## Division of Labor with the Justfile

Keep both, at different altitudes:

- **Justfile = repository policy**: git-state inspection, the `just check` gate,
  update prompting, verify step. This is _this repo's_ thinking.
- **nh = Nix interaction ergonomics**: `_build`/`_diff`/apply internals become
  `nh os test|switch` calls (`nh os switch --ask .` covers
  build+diff+confirm+activate in one). Delete the hand-rolled diff/confirm
  plumbing rather than maintaining a parallel implementation of nh.

Keep the raw `nixos-rebuild`/`nix` commands documented in
[bootstrap](../../docs/bootstrap.md): porcelain is absent on a fresh ISO and in
recovery contexts — that is where the plumbing knowledge stays load-bearing.

## Caveats

- One more tool whose flags/prompts can drift; pin it via the flake like
  everything else.
- It shields some knobs (`--option`, specialisations activation edge cases); the
  plumbing remains available underneath.
- Adopt `nvd` alone if wanting a smaller first step — but `nh` subsumes it.

## Suggested Move

Add `programs.nh` (with automatic clean) to `hardy`, rewire the Justfile's
private build/diff/apply recipes onto `nh os`, keep `check`/git-state policy in
`just`, and record before/after loop ergonomics in the ticket. One plan, low
risk, immediately felt on every iteration.

## Sources

- [nh](https://github.com/nix-community/nh)
- [nvd](https://gitlab.com/khumba/nvd)
- [nix-output-monitor](https://github.com/maralorn/nix-output-monitor)
