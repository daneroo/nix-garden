# keybinding-model

Status: active

Goal: design and verify a macOS-equivalence keybinding map for Ghostty, Brave, a
Raycast-equivalent launcher, and 1Password — covering copy/paste, tab/window
open-close-cycle, and other daily-reflex functions — tuned on `gauss` and
backported to `hardy`.

This is new ground for the repo: no keybinding-remap mechanism has been tried
here before. Treat every mechanism choice as a hypothesis to build and test on
`gauss`, not a decision to implement — prefer the simplest mechanism that passes
validation over a more capable one that hasn't been shown necessary. Working
detail, mechanism candidates, and the equivalence-map table live in
[keybinding-model](../tickets/keybinding-model.md).

Scope note: targets the current GNOME baseline on both hosts. WM-level tiling
bindings tied to `compositor-selection` (Niri vs Hyprland) are out of scope;
flag any binding that would need to change under a future compositor rather than
deciding it here.

- [x] Capture Daniel's actual macOS reflex set: walk through daily use and log
      every chord actually reached for (not just the obvious four), including
      launcher invoke, window/app switch, screenshot, lock, quit app. Update the
      ticket's function list before mapping anything. `[tier: low]`
- [x] Survey NixOS-side launcher candidates and record tradeoffs in the ticket
      (`rofi`/`wofi`, `ulauncher`, `krunner`, GNOME Activities as the baseline
      to beat). Confirm 1Password's browser-extension pairing with Brave.
      `[tier: med]`
- [x] Experiment: try the simplest mechanism first — native per-app keybinding
      config (GNOME custom keybindings, Ghostty's own config, Brave/1Password
      settings) for a handful of the captured functions. Validate each binding
      with `wev`/`keyd monitor` per
      [desktop-test-harness-fidelity](../research/desktop-test-harness-fidelity.md)
      before judging it good. Record what worked and what didn't in the ticket.
      `[tier: med]`
- [x] Only if the native-config experiment leaves gaps a per-app table can't
      close (e.g. an app with fixed, non-remappable shortcuts) — experiment with
      a global remap layer (`services.keyd` or equivalent) on `gauss` for just
      those gaps. Validate the same way. Do not adopt it fleet-wide
      pre-emptively; scope it to the functions that actually needed it.
      `[tier: high]`
- [x] Install/configure the launcher candidate chosen from the survey on `gauss`
      via the flake, following existing module conventions in
      `hosts/gauss/default.nix`. Run `just check` after edits. `[tier: med]`
- [x] Draft the first-pass equivalence map in the ticket table for all captured
      functions across all four app slots, based on what the experiments
      validated. `[tier: med]`
- [x] Implement the drafted bindings on `gauss` using whichever mechanism(s) the
      experiments actually validated per function. Run `just check` after edits.
      `[tier: med]`
- [x] Run the fidelity-ladder test procedure against the full first-pass map on
      `gauss`: objective pass via `wev`/`keyd monitor`, then feel judgment on
      real `gauss` hardware (L2+, never VNC/VM for feel). Log failures and
      feel-mismatches back into the ticket. `[tier: med]`
- [ ] Iterate bindings against test findings until the map is stable across a
      normal day of real use on `gauss`, not just a single pass. `[tier: high]`
      — genuinely still open; today was heavy same-session iteration, not real
      daily use over time. Revisit after living with it a few days.
- [ ] Finalize the equivalence map in the ticket and harvest the durable,
      settled map plus the mechanism actually chosen (and why) into `docs/` (new
      doc, e.g. `docs/keybindings.md`) — decide naming per
      [markdown.md](../../docs/markdown.md). `[tier: low]`
- [ ] Backport the finalized bindings to `hardy`, accounting for its missing
      Cmd/Super key (Chromebook layout) — re-validate the chosen mechanism there
      rather than assuming it transfers unchanged. `[tier: med]` — deliberately
      deferred; also test the Ctrl↔Meta swap alternative noted in the ticket's
      Constraints section, and the `programs._1password-gui` module (`hardy`
      currently has none, gauss's own copy was moved out of the shared
      `bootstrapPackages` this session).
- [ ] Verify the backported bindings on `hardy` using the same test procedure.
      `[tier: med]`
- [x] Resolve the ticket's open question on `programs.firefox.enable` (drop or
      justify) as part of this work, since it's adjacent leftover state in the
      same host files being touched. `[tier: low]`
- [ ] Move `keybinding-model` to `BACKLOG.md`'s `## Closed` section with outcome
      and this plan's link; decide whether to delete the ticket (after
      harvesting into `docs/`) or archive the plan. `[tier: low]`
