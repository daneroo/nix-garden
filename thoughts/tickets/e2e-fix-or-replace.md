# E2E: Fix or Replace

## Outcome

Decide whether the desktop E2E harness should be repaired, substantially
reduced, or replaced with a more maintainable testing boundary.

Do not assume the current failure deserves a narrow compatibility patch.
Preserve the useful semantic evidence, but reconsider the cost and reliability
of the suite as a whole.

## Current Failure

The first post-PaperWM Gauss run failed after 23.3 seconds:

```text
FAIL  production Ghostty and GNOME bindings are loaded
      GNOME did not restore its stock Super+N binding: @as []
```

The preceding five checks passed:

- distinct physical Alt, Ctrl, and Super delivery;
- no declared Alt-to-Super carrier;
- store-backed dotfiles;
- the patched GNOME Shell extension;
- the running keyd application mapper.

Both real hosts remained usable after deployment, logout/login, and reboot. The
failed assertion therefore identifies a mismatch between the harness's GNOME
binding expectation and the PaperWM system, not by itself a demonstrated
production regression.

## Decision Boundary

Evaluate:

- whether stock `Super+N` remains part of the desired PaperWM behavior;
- whether configuration assertions should describe intended behavior instead of
  GNOME defaults;
- which semantic tests still prevent likely regressions;
- which guided or visually unreliable cases should be removed;
- whether a smaller VM smoke test plus real-hardware acceptance is sufficient;
- whether another harness or observation boundary would cost less to maintain.

Do not expand the suite before choosing its future shape.
