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

The executable shape lives in
[the plan](../plans/archive/e2e-replace-refactor.md), split into a small
committed core and an opportunistic, cancelable bucket.

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

Finding (live): `Alt+Shift+Q` is a GNOME custom keybinding →
`gnome-session-quit --logout`. keyd carries the chord and the end-session dialog
opens. On the first run the dialog was **not** auto-cancelled — but synthetic
Escape was never cleanly tested: bun killed the test at its default 5s timeout
_during_ the observe step, before the Escape block ran, and the emergency manual
`ydotool` Escape returned a tool error (fate unknown). A physical Escape
cancelled it. So synthetic-Escape efficacy on this gnome-shell modal is
**unproven, not disproven**. The test now sets a 20s timeout so its in-body
Escape will actually run, but it stays gated behind
`NIX_GARDEN_E2E_DESTRUCTIVE_GLOBALS=1` and must first be exercised from a
logout-safe context (herdr survives logout, or a VM) where a failed cancel costs
nothing. If synthetic Escape does turn out to miss the modal, cancel via
`org.gnome.SessionManager` D-Bus. This is exactly why destructive globals belong
in the VM or an attended mode.

### VM reuse and Python deletion

Run the same Bun behavioral suite inside the NixOS VM only if the port is cheap,
reducing Python to a boot / invoke / report bridge and deleting the duplicated
Python behavioral tests once parity holds. Otherwise the Python suite stays
frozen (already unmaintained) and is deprecated later when a cheap path appears.

The runtime cost looks low: the VM inherits the host's `bun` system package, the
Bun project has no runtime dependencies, and `@types/bun` / `tsc` are dev-only
(typechecking never runs in the VM). VM invocation therefore needs only `bun`
plus the sources — no runtime packaging to design.

Finding (attempted, reverted). We tried replacing the Python behavioral
testScript with a small launcher that boots the VM and runs the live Bun suite
in daniel's session.

What we observed:

- The bridge ran and the Bun suite executed in the VM.
- `validateCapabilities` passed there with no `vm-layer` changes: passwordless
  sudo worked and keyd reported matching the ydotool device.
- The Brave scenario skipped — its lineage guard wants a Ghostty-rooted invoker,
  and the driver-launched `bun` has none.
- The Ghostty scenario did not get past focusing its fixture window: the freshly
  launched window never reached AT-SPI "active" state (10s timeout), and an
  explicit `Component.GrabFocus` call failed (busctl exited non-zero). This held
  both headless and headed (`--show`).

What we did **not** establish: why the focus failed. We did not root-cause it.
Candidates we noticed but did not confirm — software rendering (MESA/ZINK errors
in the log), `vicinae` crash-looping, paperwm's handling of the first window in
an empty workspace, window-realization timing, or an AT-SPI quirk. One
prediction was wrong: we expected the headed `--show` run to behave differently
and it failed identically, so our mental model was incomplete.

Decision (not a claim of impossibility): rather than keep digging, we reverted
and kept the Python VM suite. The Python suite reaches its results by a
different route (QEMU `send_key` + the terminal title-echo protocol) that does
not depend on the AT-SPI / WM-focus state the Bun suite asserts — a plausible
but unverified reason it works headless where this did not. Per the plan's
low-effort rule, further root-causing was not worth it now; revisit if a cheap
path or a clear cause appears.

Worth trying if revisited (two shapes, least to most promising):

1. Invoke the existing entry point (`scripts/e2e.sh` or `bun run test`) from a
   **single Python `subtest`** through the harness's proven `as_daniel` session
   handoff, rather than replacing the whole testScript. This is close to what we
   tried, so it may hit the same fixture-window focus wall for the behavioral
   scenarios — but at minimum it gives a cheap, faithful VM smoke check of the
   parts that already passed there (capability validation) while Python keeps
   the behavioral coverage.
2. **Launch the Bun run inside a real Ghostty terminal in the VM** — the Python
   harness already spawns Ghostty, so a subtest could open one and send it the
   `bun run test` command, so `bun` runs as a child of a focused terminal. This
   is the same shape Fable's analysis recommended, and it targets two of the
   three frictions at once: it satisfies the Brave lineage guard for real (a
   genuine Ghostty ancestor, not a bypass), and it may supply the
   focused-terminal / activation context that the bare `sudo … bash -lc`
   launcher never gave the fixture windows — the one thing none of our four runs
   provided, and the most plausible reason the focus grabs failed. Untested, but
   the most promising lead.

We did not test either shape.

(Aside: the boot-log noise on the driver's stderr is pre-existing and unrelated
to this attempt — `e2e-vm.sh` sends only the driver's stdout to `/dev/null` and
`--log-level warning` does not gate the serial console. Likely a QEMU
serial/console toggle; folded into the entry-point / readable-output work.)

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

Resolved: after deploying the `2333:6666` addition, keyd logs
`DEVICE: match 2333:6666 (ydotoold virtual device)` and the full guarded suite
runs green on hardy from a visible Ghostty. The only stumble was the final
clipboard-restore hitting the known Mutter wedge (unstuck by copying text) —
which now confirms the clipboard-robustness item bites on both hosts.
