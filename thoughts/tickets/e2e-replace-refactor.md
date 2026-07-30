# E2E Replace / Refactor

Follow-up after the Bun desktop E2E suite landed on `main`
(`e2e-fix-or-replace`). The suite passes on Gauss for Ghostty and Brave.

Purpose: NixOS desktops should give Daniel macOS-style keybindings and chords so
moving between machines is seamless; the E2E supports a TDD loop for growing
that mapping set. Keybindings are stable and rarely break, so this is not
regression insurance — its value is as an **exemplar** that makes adding the
next chord and its test cheap. The effort already spent exceeds its other value,
so from here: low impact implies low effort. Prefer dropping a requirement over
adding machinery, and do not reopen the solved focus or permission
investigations without new evidence. Neither Gauss nor Hardy is production.

The executable shape lives in [the plan](../plans/e2e-replace-refactor.md),
split into a small committed core and an opportunistic, cancelable bucket.

## Committed core

### Simplify so authoring is fluid

The test code should read like the truly simple test it is, and adding a new
mapped chord plus its assertion should be a small, one-place change that does
not touch the capability, monitor, injection, or cleanup plumbing. Prove it by
landing a low-hanging chord such as `Alt+W` → 1Password.

### Readable output

The run output is very hard to follow. Improve what the suite prints in normal
and slow modes so the action / wait / result sequence reads clearly.

### Rationalize the entry points

`just e2e*` and `scripts/e2e*.sh` should be consolidated behind a coherent
`just e2e` with flags, once we see how much the live and VM invocations differ.

### Record the goal in docs

State the macOS-parity keybinding goal and the e2e's exemplar purpose in
`docs/`.

### Clipboard robustness

Repeated runs wedge Mutter's clipboard: the `wl-copy` owner a run leaves behind
in cleanup eventually dies, and the compositor then hangs both `wl-copy` and
`wl-paste` until a real app re-copies. Two fixes belong here: make
`captureClipboard` treat a no-owner clipboard ("Nothing is copied") as the empty
baseline instead of crashing, and stop leaving a fragile external owner — e.g.
extend the Brave "no external clipboard client" approach to cleanup and to the
Ghostty copy/paste checks, or restore without a lingering `wl-copy`.

## Opportunistic (only if cheap)

### Remaining GNOME global bindings

Cover global chords only where a stable unattended observer and safe recovery
exist. The attended `Alt+Shift+L` lock (assert the transition, let Daniel unlock
normally, never inject a credential) and Brave `Alt+Shift+T` are candidates.
Keep deferred any action without a stable observer (logout dialog, clear-screen,
browser-find, screenshots) rather than asserting on pixels or timing.

### VM reuse and Python deletion

Run the same Bun behavioral suite inside the NixOS VM only if the port is cheap,
reducing Python to a boot / invoke / report bridge and deleting the duplicated
Python behavioral tests once parity holds. Otherwise the Python suite stays
frozen (already unmaintained) and is deprecated later when a cheap path appears.

The runtime cost looks low: the VM inherits the host's `bun` system package, the
Bun project has no runtime dependencies, and `@types/bun` / `tsc` are dev-only
(typechecking never runs in the VM). VM invocation therefore needs only `bun`
plus the sources — no runtime packaging to design.

### Hardy capability preflight fails

After deploying the merged configuration to Hardy, `./scripts/e2e.sh` fails at
the first gate — the `validateCapabilities` step "Validate the live
graphical-session capabilities". Hardy itself and its keybindings are fine and
the VM test still passes; only the live harness preflight fails. That single
step bundles roughly a dozen assertions (executables, session env, Wayland
socket, GNOME Shell bus, keyd/ydotoold services, sudo, ydotool, the
keyd↔ydotoold device match, AT-SPI, extensions), so the failure does not name
which assumption breaks on Hardy. Making the check name the exact failing
capability is both the fix and a simplification win. Likely needs a handoff to a
Claude running on Hardy.

Root cause (diagnosed over SSH): keyd
`DEVICE: ignoring 2333:6666 (ydotoold virtual device)`. Hardy deliberately
scopes keyd to the internal keyboard
(`keyboards.internal.ids = [ "0001:0001:09b4e68d" ]`) for its Chromebook
`Alt+F6/F7 → kbdillum` remap, whereas gauss uses `[ids] *`. So keyd ignores the
ydotool injection device and synthetic chords never traverse keyd; the physical
keyboard (and thus real keybindings) still work. Fix: list ydotool's `2333:6666`
in hardy's keyd ids so keyd manages the injection device. Still open: the
preflight bundles ~a dozen checks and does not name the failing one — split it
as part of the readability work.
