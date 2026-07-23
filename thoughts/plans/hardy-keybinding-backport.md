# hardy-keybinding-backport

Status: active

Goal: restore `hardy` as a fully usable daily machine with keyboard
illumination, working 1Password, and Brave integration, then bring it as close
as its Chromebook keyboard permits to the macOS-equivalence baseline `gauss`
reached in `keybinding-model`. Working detail in
[hardy-keybinding-backport](../tickets/hardy-keybinding-backport.md).

Create a branch named after this plan's slug before executing, per
[workflow.md](../../docs/workflow.md#plans).

- [x] Coordinate non-physical execution from the current workspace over SSH to
      `daniel@192.168.2.40`: confirm Hardy's repository, running generation, and
      working tree are safe before mutation. Continue using the LAN address
      until Tailscale and `hardy.ts.imetrical.com` are available; do not depend
      on `hardy.imetrical.com`. When raw physical key presses or feel judgments
      become the blocking input, prepare an explicit state-and-command handoff
      for Codex running on Hardy with Daniel assisting. `[tier: high]`
- [x] Restore keyboard illumination as an early independent checkpoint. Preserve
      the confirmed working `chromeos::kbd_backlight` LED interface and the
      immediate `50/100` recovery, determine why systemd restored a saved value
      of zero, and make a sane nonzero level survive reboot. With Daniel or
      on-Hardy Codex supplying physical input, capture the backlight-key chords
      and distinguish missing top-row events from missing userspace handling;
      then restore working brightness-down/up controls without coupling them to
      the eventual Cmd/Option mapping. `[tier: high]`
- [ ] Restore 1Password as an independently deployable checkpoint: add
      `programs._1password-gui` with `polkitPolicyOwners = [ "daniel" ]` and
      `programs._1password` to `hardy`; run `just check`, commit, run
      `just plan` on `hardy`, inspect the closure, and apply with Daniel's
      authorization. Verify the GUI launches,
      `/run/wrappers/bin/1Password-BrowserSupport` exists with the expected
      setgid wrapper, and the Brave extension can talk to the desktop app.
      `[tier: high]`
- [x] Capture `hardy`'s input truth before choosing a remap: with `keyd`
      stopped, record device IDs and raw events for both Ctrl/Alt keys,
      Search/Launcher, and relevant Chromebook top-row keys; also record the
      actual GNOME Shell version and existing local dconf overrides for
      candidate chords. Define whether the internal and any external keyboards
      need separate mappings. `[tier: high]`
- [ ] Compare base-layer candidates on the physical keyboard. Trial the smallest
      mapping that can provide distinct, usable Cmd-equivalent, Option, and
      native Control roles; specifically test whether the Cmd-position key
      emitting native Ctrl closes most Linux-app gaps. Do not assume either
      `gauss`'s Alt↔Super swap or a Ctrl↔Meta swap. Keep SSH recovery available,
      use exact device IDs where practical, and verify `keyd`'s emergency
      termination chord before persisting the mapping. `[tier: high]`
- [ ] Implement and live-validate Ghostty and Brave against the chosen logical
      modifier, starting with native Ctrl behavior. Cover copy/paste, tab
      new/close/reopen/cycle, new window, address-bar focus, Find, terminal
      clear, and the contextual close behavior. `[tier: med]`
- [ ] Only if the native base layer leaves demonstrated Brave gaps, add
      `keyd-application-mapper`. Before validating it, check `hardy`'s GNOME
      Shell version and install an unpatched, Gauss-equivalent, or differently
      patched extension as required. Do not carry over Gauss's broad
      `Group = "users"` socket permission. `[tier: high]`
- [ ] Install and validate the launcher (Vicinae, per `gauss`'s result) on
      `hardy`, binding launcher invocation and 1Password Quick Access to the
      physical chords selected above. `[tier: med]`
- [x] Reconcile GNOME conflicts and mutable user state: inspect each relevant
      effective `gsettings` value, reset only conflicting local overrides or
      deliberately lock settings where enforcement is warranted, and confirm the
      declarative values survive logout and reboot. `[tier: med]`
- [ ] Verify the complete Hardy acceptance map live on its physical keyboard,
      using the same objective event checks and real-hardware judgment as
      `keybinding-model`. Include app/window switching, launcher, lock,
      screenshot, keyboard-backlight controls, 1Password, Brave integration, and
      every app binding above; record intentional gaps rather than forcing
      unsafe or incoherent equivalence. Run `just check` and `just plan` before
      the final apply. `[tier: high]`
- [ ] Clean up the durable documentation while harvesting Hardy's results:
      update [docs/keybindings.md](../../docs/keybindings.md) with per-host
      modifier/mechanism tables, fix its duplicate/misaligned close-window rows
      and stale browser-extension limitation wording, resolve the old ticket's
      still-open capture note, correct the 1Password wrapper terminology, and
      add `keybindings.md` to `docs/README.md` and `docs/file-layout.md`.
      `[tier: low]`
- [ ] Move `hardy-keybinding-backport` to `BACKLOG.md`'s `## Closed` section
      with outcome and this plan's link. `[tier: low]`
