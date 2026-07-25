# desktop-test-harness

Status: planned

Goal: build a VM workbench that boots any host's configuration for hands-on
experimentation and can also assert one real keybinding headlessly, so that
keybinding consolidation and compositor experiments become reversible. Working
detail in [desktop-test-harness](../tickets/desktop-test-harness.md).

Create a branch named after this plan's slug before executing, per
[workflow.md](../../docs/workflow.md#plans).

Stop after the single-chord check passes. Widening the suite is deliberately out
of scope for this plan; it belongs to whichever desktop work runs next.

- [ ] Boot `gauss`'s configuration unmodified in a VM and record what actually
      happens. Run `nixos-rebuild build-vm --flake .#gauss` and
      `./result/bin/run-gauss-vm`; capture whether it reaches a graphical GNOME
      session or a console, what the login state is, how long the build takes,
      and what warnings appear. Do not fix anything yet — this step exists to
      replace assumptions with observations. `[tier: med]`
- [ ] Make the VM reach a usable desktop session. Expect to need a VM-only
      configuration layer: autologin, a display resolution, and `virtio-gpu-gl`
      with a local GTK/SDL display so the guest receives raw scancodes including
      Super. Keep this layer clearly separated from host configuration; it must
      not alter what `just plan` would apply to a real machine. Confirm Super
      and Alt arrive intact using `wev` inside the guest. `[tier: high]`
- [ ] Add a `just vm HOST` recipe wrapping build and run, defaulting sensibly
      and working for both `gauss` and `hardy`. Note in its help text that VM
      mode ignores `hardware-configuration.nix` filesystems. Run `just check`.
      `[tier: low]`
- [ ] Determine whether `keyd` and the application mapper function inside the
      guest, since the mapper depends on a patched GNOME Shell extension. If
      they do not, record precisely what fails and which layer of the keybinding
      path the harness can therefore still verify. This result decides how much
      of the keybinding model is testable in a VM at all, so capture it in the
      ticket before proceeding. `[tier: high]`
- [ ] Prove one chord by hand in the headed VM: press the copy chord in Ghostty,
      confirm with `wl-paste` that the clipboard changed. This is the manual
      version of the assertion that the next step automates. `[tier: med]`
- [ ] Reproduce the same chord through the NixOS test driver. Write a minimal
      `runNixOSTest` for the trial host, build its `.driverInteractive`
      attribute, and drive `send_key` plus a `wl-paste` assertion from the REPL
      until the sequence is reliable. Record the working sequence verbatim.
      `[tier: high]`
- [ ] Commit that sequence as a headless check under `checks.<system>`, exposed
      through a `just` recipe. Keep it out of `just check` if it is slow; state
      the decision and its basis. Verify it fails when the binding is wrong — an
      assertion that has never failed has not been tested. `[tier: med]`
- [ ] Harvest durable facts: document the workbench and its three drive modes in
      `docs/`, index it per [docs/README.md](../../docs/README.md) and
      `docs/file-layout.md`, and state explicitly what the harness verifies
      versus what still requires real hardware. Delete the ticket, and move
      `desktop-test-harness` to the backlog's `## Closed` section. `[tier: low]`
