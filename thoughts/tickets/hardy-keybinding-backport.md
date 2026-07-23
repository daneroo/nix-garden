# hardy-keybinding-backport

Carries forward the `hardy`-specific work split out of `keybinding-model` when
that ticket closed 2026-07-23 (validated and settled on `gauss`). See
[keybinding-model](keybinding-model.md) for the full validation trail, mechanism
comparisons, and bugs found — this ticket only tracks what's specific to
`hardy`.

## End state

- 1Password is installed again through the correct NixOS modules, its desktop
  app works, and Brave's extension can communicate with it.
- Brave and Ghostty are fully usable for Daniel's daily reflexes.
- The internal Chromebook keyboard has the sanest achievable mapping of
  Cmd-equivalent, Option, and native Control roles, based on observed key events
  rather than Gauss assumptions.
- Launcher, lock, screenshot, app/window switching, and the settled app bindings
  have been validated live on Hardy's physical keyboard.
- Differences from Gauss or macOS are deliberate, documented, and less costly
  than the mechanism that would be required to erase them.

## Execution topology

- Coordinate configuration, builds, service inspection, and other non-physical
  validation from the current workspace over SSH to `daniel@192.168.2.40`.
- Use the LAN address until Tailscale is running and `hardy.ts.imetrical.com`
  exists. Do not plan around `hardy.imetrical.com`; a Bell Giga Hub reservation
  bug currently prevents a stable LAN DNS path under that name, and fixing the
  router is out of scope.
- When progress requires physical key presses or feel judgments, hand off the
  exact current state, remaining commands, test matrix, and expected
  observations to Codex running locally on Hardy. Daniel will assist with the
  physical input and subjective validation.

## Why this is its own ticket, not a keybinding-model step

Daniel did not want `hardy` work happening on the now-closed `keybinding-model`
branch. `hardy` backport is real, separate work with its own constraint (see
below), not a continuation of the merged branch.

## Current regression to repair first

After applying merged `main` to `hardy` on 2026-07-23, 1Password disappeared as
expected from the closure: the shared plain `_1password-gui` package was removed
when Gauss adopted the proper NixOS module, but Hardy did not receive that
module. Restore it before keyboard experimentation so Hardy returns to its prior
functional baseline.

## Constraint

`hardy` has no physical Cmd/Super key (Chromebook keyboard, ASUS Flip C436F) — a
fundamentally different problem than `gauss`'s "which key plays which role,"
which the whole `gauss` mechanism assumed a standard PC keyboard for.
Re-validate the chosen mechanism there; do not assume it transfers unchanged.

## Carried-forward facts

- **Alternative base-layer strategy to consider**: the
  `stevenilsen123/mac-keyboard-behavior-in-linux` project swaps Ctrl↔Meta for
  Mac keyboards but Ctrl↔Alt for Windows/Linux keyboards, treating physical Alt
  as Command in the latter case. Hardy fits neither assumption cleanly until its
  Search/Launcher and modifier events are observed. The useful hypothesis is
  narrower: a Cmd-position physical key that emits native `Ctrl` may use common
  Linux shortcuts directly and sidestep much of the per-app remapping Gauss
  needed. Test that hypothesis first; do not assume a particular symmetric swap.
- **`programs._1password-gui` module**: `hardy` currently has none — 1Password
  was moved out of the shared `flake.nix` `bootstrapPackages` during
  `keybinding-model` work. The module installs the `1Password-BrowserSupport`
  setgid wrapper required for browser integration; `polkitPolicyOwners`
  separately enables the package's polkit integration for Daniel. `hardy` needs
  the same module treatment `gauss` got, plus live verification of the GUI and
  Brave integration.
- **`keyd` GNOME Shell extension version**: `gauss` needed patching (upstream
  only declares Shell 45-49 support). It is only relevant if Hardy still needs
  `keyd-application-mapper`; if so, check Hardy's actual GNOME Shell version
  before assuming the same patch is needed unchanged.
- **Mutable dconf state**: system dconf databases provide defaults, while local
  user values win unless locked. Inventory effective values and local overrides
  before diagnosing a binding failure or declaring the result converged.
- Full settled `gauss` equivalence map:
  [docs/keybindings.md](../../docs/keybindings.md).

## Documentation cleanup in scope

Harvesting Hardy's result is also the right time to fix the small
inconsistencies found in the merged durable documentation: the close-window
rows, the stale Chrome-extension rationale for gaps that
`keyd-application-mapper` could reach, the old ticket's incomplete capture note,
1Password wrapper terminology, and the missing docs index entries. This cleanup
clarifies the two-host result and does not expand the runtime implementation.

## Not carried forward (deliberately)

- Multi-day real-use stability iteration on `gauss` — not a todo. Issues surface
  naturally; log them in `BACKLOG.md` as they come up, and open a new
  ticket/plan only if enough accumulate to warrant one.
