# E2E Replace / Refactor

Status: planned

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
- [ ] **Readable output.** _(Partial: dropped the raw keyd-evidence dumps and
      now assert evidence before the behavioral outcome.)_ Improve normal and
      slow output so the action / wait / result sequence reads top to bottom
      without tool internals leaking. Acceptance: a full run is followable
      without the source open. `[tier: low]`
- [ ] **Rationalize the entry points.** Consolidate `just e2e*` and
      `scripts/e2e*.sh` behind a coherent `just e2e` with flags once we see how
      much the live and VM invocations really differ. `[tier: low]`
- [ ] **Record the goal in docs.** State the macOS-parity keybinding goal and
      the e2e's exemplar purpose in `docs/`. `[tier: low]`

## Opportunistic — only if cheap, explicitly cancelable

- [ ] **A few more GNOME globals**, only where a stable unattended observer and
      safe recovery exist; attended `Alt+Shift+L` lock only if it stays trivial
      (assert the transition, Daniel unlocks, never inject a credential). Defer
      anything without a stable observer. `[tier: med]`
- [ ] **VM runs the Bun content.** Only if the port is cheap: run the same Bun
      suite inside the NixOS VM with Python reduced to boot / invoke / report,
      then delete the Python behavioral content. Otherwise the Python suite
      stays frozen (already unmaintained) and we deprecate it later when a cheap
      path appears. `[tier: high]`
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
