# Visible VM Session Actions

Observed on 2026-07-28 after applying the simplified native-Alt model to Gauss:

- `just e2e-vm --host gauss --show` injected Alt+Shift+L and reported the guided
  subtest as passing, but Daniel did not see the visible VM lock.
- The test's keyd monitor evidence still showed the intended physical
  Alt+Shift+L event sequence.
- Daniel also reported that the guided Alt+Shift+Q injection did not visibly
  open GNOME's logout confirmation dialog in the same visible VM workflow.
- Alt+Shift+L locked the real Gauss session correctly on generation 23.
- Alt+Shift+Q opened the logout confirmation dialog correctly on real Gauss.
- Headless GNOME was already known to ignore the correctly emitted accelerator;
  the test deliberately does not claim a semantic lock assertion there. The
  logout-dialog case likewise asserts only the session precondition and survival
  after Escape, not the dialog consequence.

This is a non-blocking harness-fidelity bug, not a production keybinding
failure. Do not reopen the resolved screenshot/lock investigation as part of
`simplified-keybinding-model`; no fix is requested in that plan.

Future work should determine why the visible VM misses both session-action
consequences and should keep each action and four-second pause identical in
headless and visible modes. Passing guided subtests must continue to avoid
claiming that either consequence was asserted.
