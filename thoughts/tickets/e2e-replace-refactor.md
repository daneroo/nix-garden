# E2E Replace / Refactor

Follow-up after the Bun desktop E2E suite landed on `main`
(`e2e-fix-or-replace`). The suite passes on Gauss for Ghostty and Brave. These
items make it broader, simpler, clearer, and reusable in the VM. Each is
independent; do not reopen the solved focus or permission investigations without
new evidence.

## Remaining GNOME global bindings

Cover the global chords not yet tested:

- attended `Alt+Shift+L` lock — assert the lock transition, let Daniel unlock
  normally, never inject a credential;
- Brave `Alt+Shift+T` reopen-closed-tab.

Keep deferred any action without a stable semantic observer (logout dialog,
clear-screen, browser-find, screenshots) rather than asserting on pixels or
timing.

## Simplification

The test code should read like the truly simple test it is. Examine the Bun
sources for duplication and incidental complexity and reduce them, without
weakening the working input, observation, and cleanup foundation.

## Readable output

The run output is very hard to follow. Examine and improve what the suite prints
in normal and slow modes so the sequence of actions, waits, and results reads
clearly.

## VM reuse and Python deletion

Examine running the same Bun behavioral suite inside the NixOS VM, reducing
Python to a boot / invoke / report bridge, and deleting the duplicated Python
behavioral tests once parity holds.
