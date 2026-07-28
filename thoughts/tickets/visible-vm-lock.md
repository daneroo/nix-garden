# Visible VM Lock

Observed on 2026-07-28 after applying the simplified native-Alt model to Gauss:

- `just e2e-vm --host gauss --show` injected Alt+Shift+L and reported the guided
  subtest as passing, but Daniel did not see the visible VM lock.
- The test's keyd monitor evidence still showed the intended physical
  Alt+Shift+L event sequence.
- Alt+Shift+L locked the real Gauss session correctly on generation 23.
- Headless GNOME was already known to ignore the correctly emitted accelerator;
  the test deliberately does not claim a semantic lock assertion there.

This is a non-blocking harness-fidelity bug, not a production keybinding
failure. Do not reopen the resolved screenshot/lock investigation as part of
`simplified-keybinding-model`; no fix is requested in that plan.

Future work should determine why the visible VM also misses the lock consequence
and should keep the action and four-second pause identical in headless and
visible modes. A passing guided subtest must continue to avoid claiming that the
lock consequence was asserted.
