# E2E Replace / Refactor

Status: done

## Outcome

Concluded. The exemplar landed: the live Bun suite is simple to extend
(`pressChord`, `brave.ts`), its output is readable (quiet-on-success /
loud-on-failure on stderr), Hardy runs green, and the first GNOME global exists
(gated, opt-in). `just e2e` and `just e2e-vm` now share one calling convention.

Deliberately dropped or deferred rather than pursued — per this plan's own
low-impact / low-effort rule, now that the exemplar exists:

- **Running the Bun suite in the VM** — attempted and reverted. The VM's window
  focus behaviour blocks the Bun suite's assertions and we did **not**
  root-cause it. The Python VM suite stays as the VM behavioural path; see the
  ticket finding for what to try if revisited (most promising: launch the Bun
  run inside a real Ghostty terminal).
- **Clipboard robustness, recording the goal in `docs/`, boot-log stderr
  quieting, and deeper entry-point consolidation** — left undone; low value
  against the effort. `Alt+W` → 1Password still needs a keyd deploy.

Nothing here is a blocker; the suite is useful as-is.

## Why this exists

NixOS desktops should give Daniel macOS-style keybindings and chords so moving
between machines is seamless. That mapping set is incomplete and may never be
complete, but what already works helps a lot. This E2E was meant to support a
TDD loop for growing those mappings.

Keybindings are stable — once proved they rarely break — so this is not
regression insurance. Its real value is as an **exemplar**: a clean,
reproducible pattern (Bun on the live session, plus the Nix-Way VM) that makes
_adding the next chord and its test_ cheap. The effort already spent exceeds any
other value it has. Therefore: low impact implies low effort.

## Guiding rule

Prefer dropping a requirement over adding machinery. Stop any item the moment
its effort outpaces its exemplar value, and revisit the assumption rather than
engineer around it. Do not reopen the solved focus or permission investigations
without new evidence. Run live suites serially, only from a visible Ghostty
session. Neither Gauss nor Hardy is production; this is homelab nixification and
a smooth Linux desktop.

Assumption to revisit: the non-VM suite requires a visible-Ghostty invoker
lineage and refuses Herdr-rooted invocation. That fights Daniel's usual workflow
of driving agents from galois over SSH into gauss and hardy (asymmetric: galois
reaches the hosts, not the reverse). If the lineage guard obstructs fluid
authoring or the Hardy handoff, question whether it is really needed before
adding machinery to work around it.

## Committed core — the one investment worth making

- [x] **Simplify so authoring is fluid.** A `pressChord` helper collapses the
      checkpoint/inject/assert idiom to one line per chord, and the Brave
      plumbing moved to `brave.ts` (`brave.test.ts` 1062 → ~555 lines) so the
      test reads as behavior. Clipboard capture/restore was also dropped for a
      warning + end-of-run clear. Remaining as a cheap proof: land `Alt+W` →
      1Password (needs a keyd deploy). `[tier: med]`
- [x] **Readable output.** The reporter now runs entirely on stderr (meshing
      with bun:test's own stream), indents by nesting depth, prints one `✓`/`✗`
      line per step, and keeps waits silent on success but loud on failure. A
      green run is a clean checklist; a failure shows the exact `✗` step plus
      the detail bun prints from the throw. Live `\r` animation was dropped as
      unneeded. `[tier: low]`
- [ ] **Rationalize the entry points** — _after_ the VM investigation, since the
      VM invocation shape informs the unified interface. Consolidate `just e2e*`
      and `scripts/e2e*.sh` behind a coherent `just e2e` with flags once we see
      how much the live and VM invocations really differ. `[tier: low]`
- [ ] **Record the goal in docs.** State the macOS-parity keybinding goal and
      the e2e's exemplar purpose in `docs/`. `[tier: low]`

## Opportunistic — only if cheap, explicitly cancelable

- [ ] **The first GNOME global.** The suite covers none yet — every chord today
      is app-scoped and there is no Super/Meta key. Add exactly one to establish
      the pattern: `Alt+Shift+Q`, which opens GNOME's end-session (log out)
      dialog. Prove keyd carries the chord, observe the dialog through a stable
      observer (AT-SPI), then **Escape-cancel it and assert it is dismissed** —
      never confirm log out, and never the lock chord (harder to undo). The old
      Python/VM suite ended with lock-then-exit; deliberately avoid that. Defer
      anything without a stable observer. `[tier: med]`
- [x] **VM runs the Bun content — attempted, reverted; root cause not
      established.** We tried a launcher that boots the VM and runs the live Bun
      suite in daniel's session. Observed: the bridge runs, and
      `validateCapabilities` passes in the VM with no `vm-layer` changes
      (passwordless sudo worked and keyd reported matching the ydotool device).
      The Brave scenario skipped (its lineage guard wants a Ghostty-rooted
      invoker; the driver-launched `bun` has none). The Ghostty scenario stalled
      at focusing its fixture window — the freshly launched window never reached
      AT-SPI "active" (10s timeout), and an explicit `Component.GrabFocus` call
      failed (busctl exited non-zero) — both headless and headed (`--show`). We
      did **not** root-cause that failure; candidates we noticed but did not
      confirm include software rendering, `vicinae` crash-looping, paperwm's
      handling of the first window in an empty workspace, window-realization
      timing, and AT-SPI quirks. One prediction was wrong (we expected `--show`
      to differ; it failed identically), so our model was incomplete. The Python
      VM suite reaches results without depending on WM/AT-SPI focus (QEMU
      `send_key` + the terminal title-echo protocol) — a plausible but
      unverified reason it works where this did not. Decision (not a proof of
      impossibility): rather than keep digging, we reverted and kept the Python
      VM suite; per the plan's low-effort rule further root-causing was not
      worth it now. Revisit if a cheap path or a clear cause appears.
      `[tier: high]`
- [x] **Fix the Hardy preflight.** Hardy scoped keyd to the internal keyboard,
      so it ignored ydotool's `2333:6666` device; adding that id to hardy's keyd
      config lets synthetic chords traverse keyd, and the full guarded suite now
      runs green on hardy. (The bundled preflight still does not name the
      failing check — folded into Readable output.) `[tier: med]`

## Deferred unless a concrete need appears

Nix-packaging the Bun suite, a Go sibling, a concurrency lock, non-GNOME hosts.

## Verification

`just check` after edits; one serial live run per change from a visible Ghostty;
`just e2e-vm` only if we touch the VM path.
