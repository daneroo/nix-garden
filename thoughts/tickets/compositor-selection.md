# compositor-selection — Choose a Compositor to Replace GNOME

Decision inputs gathered so far. Daniel does not yet know enough to choose; this
records what is known and what would settle it, rather than deciding.

## Current Lean

Niri, on the expectation that its column-based scrolling-tiling model suits
Mac-trained muscle memory better than Hyprland's grid tiling. This is a
hypothesis, not evidence — it is exactly the kind of claim
[desktop-test-harness](desktop-test-harness.md) exists to make cheap to test.

## What Leaving GNOME Buys

- Removes the patched GNOME Shell extension currently required just to run
  `keyd`'s application mapper — a hack maintained against an untested Shell
  version.
- Removes GNOME's bundled default-application census (Calendar, Weather, Maps,
  and the rest) that arrives with `services.desktopManager.gnome.enable`.
- Frees the GNOME-owned chords that the native-Alt candidate in
  [simplified-keybinding-model](../design/simplified-keybinding-model.md)
  collides with, notably Alt+Space.

## What It Does Not Buy

Per-application keybinding mapping remains necessary regardless of compositor.
GTK and Qt can in principle be bulk-configured through a shortcut scheme or key
theme, but GTK4/libadwaita has closed that off, and the Electron daily-drivers
(VSCode, Slack, Discord, Brave) ignore both mechanisms entirely. No compositor
choice removes the per-app layer for that bucket. Do not adopt a compositor
expecting keybinding consolidation to fall out of it.

## Rejected

- **Omarchy** (Hyprland-based, opinionated defaults). Neovim-centric in a way
  that does not fit a non-Neovim workflow. `gauss` previously ran it.

## Sequencing

The keybinding model and the VM workbench come first. Once the shared keybinding
modules exist, a compositor trial should re-point them rather than rebuild them,
and the test suite should transfer with only the window-state probe swapping
(`wmctrl` -> `niri msg` or `hyprctl`).

## Open

- Does a VM trial support a real choice between Niri and Hyprland, or only
  eliminate one? Feel cannot be judged through virtualization; a genuine
  decision may need a NixOS `specialisation` boot entry on real hardware, or
  daily use on a disposable host.
- Which host hosts the trial, and on what branch?
- What replaces GNOME's session pieces (lock, screenshot, logout, notifications,
  display configuration) — all currently bound and validated in
  [docs/keybindings.md](../../docs/keybindings.md)?
- Does the compositor scaffold justify adopting `flake-parts` plus wrapper
  modules now, against the staged advice in
  [module-architecture](../research/module-architecture.md)? Taking Vimjoyer's
  `flake-parts-wrapped-template` wholesale is defensible as infrastructure, but
  it supersedes that note's sequence and should be recorded as a decision.
