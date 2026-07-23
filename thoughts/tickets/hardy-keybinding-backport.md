# hardy-keybinding-backport

Carries forward the `hardy`-specific work split out of `keybinding-model` when
that ticket closed 2026-07-23 (validated and settled on `gauss`). See
[keybinding-model](keybinding-model.md) for the full validation trail, mechanism
comparisons, and bugs found — this ticket only tracks what's specific to
`hardy`.

## Why this is its own ticket, not a keybinding-model step

Daniel doesn't want `hardy` work happening on the `keybinding-model` branch —
that branch is closing and merging to `main` once `gauss`'s work is harvested.
`hardy` backport is real, separate, deferred work with its own constraint (see
below), not a loose end of the same plan.

## Constraint

`hardy` has no physical Cmd/Super key (Chromebook keyboard, ASUS Flip C436F) — a
fundamentally different problem than `gauss`'s "which key plays which role,"
which the whole `gauss` mechanism assumed a standard PC keyboard for.
Re-validate the chosen mechanism there; do not assume it transfers unchanged.

## Carried-forward facts

- **Alternative base-layer strategy to consider**: the
  `stevenilsen123/mac-keyboard-behavior-in-linux` keyd config swaps
  **Ctrl↔Meta** rather than Alt↔Super, so its "Cmd" key physically emits `Ctrl`
  — already a common native close/shortcut modifier across many Linux apps,
  sidestepping much of the per-app remapping `gauss` needed. Given `hardy`'s
  missing key entirely (not just "which key plays which role"), this may be a
  genuinely better fit there than replicating `gauss`'s Alt↔Super swap verbatim.
  Worth trying first, not assumed correct.
- **`programs._1password-gui` module**: `hardy` currently has none — 1Password
  was moved out of the shared `flake.nix` `bootstrapPackages` during
  `keybinding-model` work (needs a per-host `polkitPolicyOwners` override to get
  the `1Password-BrowserSupport` setuid wrapper; the plain package alone doesn't
  provide browser-extension integration). `hardy` needs the same module
  treatment `gauss` got.
- **`keyd` GNOME Shell extension version**: `gauss` needed patching (upstream
  only declares Shell 45-49 support) — check `hardy`'s actual GNOME Shell
  version before assuming the same patch is needed unchanged.
- Full settled `gauss` equivalence map:
  [docs/keybindings.md](../../docs/keybindings.md).

## Not carried forward (deliberately)

- Multi-day real-use stability iteration on `gauss` — not a todo. Issues surface
  naturally; log them in `BACKLOG.md` as they come up, and open a new
  ticket/plan only if enough accumulate to warrant one.
