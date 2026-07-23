# hardy-keybinding-backport

Status: planned

Goal: bring `hardy` up to the same macOS-equivalence keybinding baseline `gauss`
reached in `keybinding-model`, accounting for `hardy`'s missing physical
Cmd/Super key rather than assuming the `gauss` mechanism transfers unchanged.
Working detail in
[hardy-keybinding-backport](../tickets/hardy-keybinding-backport.md).

Create a branch named after this plan's slug before executing, per
[workflow.md](../../docs/workflow.md#plans).

- [ ] Try the Ctrl↔Meta base-layer swap (per the carried-forward
      `stevenilsen123/mac-keyboard-behavior-in-linux` reference) on `hardy` as
      the first candidate, given the missing-key constraint is different in kind
      from `gauss`'s — not a given that `gauss`'s Alt↔Super swap is the right
      fit here. `[tier: high]`
- [ ] Re-implement (or confirm reusable as-is) the `keyd` + per-app
      configuration for Ghostty and Brave on `hardy`, re-validating each binding
      live rather than assuming parity with `gauss`. `[tier: med]`
- [ ] Check `hardy`'s actual GNOME Shell version and confirm whether the `keyd`
      GNOME extension version patch `gauss` needed is still required, unneeded,
      or needs a different patch. `[tier: med]`
- [ ] Add the `programs._1password-gui` module (with `polkitPolicyOwners`) to
      `hardy`'s own config -- it currently has none; 1Password was moved out of
      the shared `flake.nix` `bootstrapPackages` during `keybinding-model`.
      `[tier: low]`
- [ ] Install and validate the launcher (Vicinae, per `gauss`'s result) on
      `hardy`. `[tier: med]`
- [ ] Verify the full backported map on `hardy` using the same test procedure
      `keybinding-model` used (live validation, not just config review).
      `[tier: med]`
- [ ] Update [docs/keybindings.md](../../docs/keybindings.md) to reflect
      `hardy`-specific results once settled. `[tier: low]`
- [ ] Move `hardy-keybinding-backport` to `BACKLOG.md`'s `## Closed` section
      with outcome and this plan's link. `[tier: low]`
