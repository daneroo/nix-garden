# E2E Replace / Refactor

Status: planned

Goal: make the first-of desktop E2E simpler and clearer, get it running on
Hardy, and reuse it in the VM — dropping scope rather than engineering around it
whenever a step gets hard.

Guiding rule: this is low-value, first-of regression evidence, not a desktop
automation platform. Prefer deleting a requirement over adding machinery. When a
step gets complicated, stop and revisit the assumption or requirement before
continuing. Do not reopen the solved focus or permission investigations without
new evidence. Run live suites serially, only from a visible Ghostty session.

- [ ] **Hardy parity via a legible capability check.** Reproduce the Hardy
      `validateCapabilities` failure and find the one assumption that breaks.
      Split the monolithic check so any failure names the exact missing
      capability, then fix or drop the failing assumption — drop it if it is not
      truly required. Acceptance: the guarded suite reaches injection on Hardy
      from a visible Ghostty, or clearly reports why it skips. `[tier: med]`
- [ ] **Simplify the sources to read like a simple test.** Reduce duplication
      and incidental complexity in the Bun sources and test files without
      weakening the working input, observation, and cleanup foundation.
      Acceptance: each scenario reads as a plain behavioral description.
      `[tier: med]`
- [ ] **Make the run output readable.** Improve normal and slow output so the
      action / wait / result sequence reads top to bottom without tool internals
      leaking. Acceptance: a full run is followable without the source open.
      `[tier: low]`
- [ ] **Remaining GNOME globals, attended.** Add only chords with a stable
      semantic outcome and safe recovery: attended `Alt+Shift+L` lock (assert
      the transition, Daniel unlocks, no credential) and Brave `Alt+Shift+T`.
      Defer anything without a stable observer. `[tier: med]`
- [ ] **Reuse the suite in the VM; delete Python behavior.** Run the same Bun
      suite inside the NixOS VM, reduce Python to boot / invoke / report, and
      delete the duplicated Python behavioral tests after parity. If this
      balloons, stop and reconsider whether VM parity is worth it now.
      `[tier: high]`

Deferred unless a concrete need appears: Nix-packaging the Bun suite, a Go
sibling, a concurrency lock, and non-GNOME hosts.

Verification: `just check` after edits; one serial live run per change from a
visible Ghostty; `just e2e-vm` for the VM step.
