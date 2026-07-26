# Desktop Test Harness

Status: done

Goal: make desktop configuration changes observable and testable in VMs before
changing a real host.

## Outcome

One public command now owns the three VM workflows through `scripts/e2e-vm.sh`:

- `just e2e-vm` runs all assertions headlessly in a fresh VM.
- `just e2e-vm --show` runs the same assertions in a visible fresh VM.
- `just e2e-vm --no-test --host HOST` opens a persistent exploratory VM.

The native NixOS test-driver suite imports the real gauss configuration plus a
VM-only layer. It shares one VM across its scenarios and verifies declared
dotfiles, the keyd mapper and GNOME extension, production bindings, Ghostty
copy/paste/tab/window behavior, and GNOME lock/authenticate/unlock. The durable
approach, tradeoffs, and fidelity boundary are in
[e2e-testing](../../../docs/e2e-testing.md).

`just check` remains the separate pre-commit invariant gate and never boots a
desktop VM.

## Verification

- A deliberately unbound chord failed the lock assertion, proving the harness
  could report a real behavioral failure.
- Repeated headless runs booted fresh QEMU processes and passed all twelve
  assertions.
- Daniel watched repeated visible runs and confirmed the application, tab,
  window, clipboard, lock, and unlock transitions.
- The unified script's headless and visible modes passed after the command
  consolidation.
- `just check` passed after the final implementation.

## What the Failed Iterations Established

- Building a cached Nix derivation is not test execution. Assertion modes invoke
  the driver directly, so every run boots a VM.
- A visible VM is not evidence that its test script ran. Visible mode uses the
  same script and reporting path as headless mode.
- Parallel pytest and native-driver containers added plumbing without adding
  isolation. The surviving suite uses the native driver and one shared VM.
- Fresh desktop state matters. GNOME Tour is disabled, and the suite establishes
  a focused Ghostty surface before injecting application chords.
- Application behavior requires application-specific observation. Ghostty uses a
  terminal-protocol fixture, clipboard bytes, and AT-SPI titles; GNOME uses its
  own systemd and D-Bus boundaries.
- Invalid empty GVariant declarations left GNOME's default `Super+N` binding
  active and intercepted Ghostty. Both hosts now declare an empty array of
  string elements correctly.
- A fresh home exposed unsafe root-owned tmpfiles parent directories. The
  stopgap remains tracked separately as `home-config-ownership`.

## Deferred

- Display-device and compositor-feel decisions belong to `compositor-selection`
  and require real-hardware judgment.
- Replacing the tmpfiles stopgap belongs to `home-config-ownership`.
- Applying the merged configuration to gauss and hardy is a deployment step,
  performed only when Daniel explicitly requests it.
