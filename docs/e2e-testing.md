# End-to-End (E2E) Testing

The desktop workbench boots a host's declared configuration in a VM. The same
VM-only configuration layer supports unattended regression, visible
demonstration, and hands-on exploration without changing a real host.

## Modes

| Mode                  | Command or mechanism                             | State      | Assertions |
| --------------------- | ------------------------------------------------ | ---------- | ---------- |
| Headless regression   | `just e2e-vm`                                    | Disposable | Yes        |
| Visible regression    | `just e2e-vm --show`                             | Disposable | Yes        |
| Headed exploration    | `just e2e-vm --no-test --host HOST`              | Persistent | No         |
| Interactive authoring | Build and run `.#test-desktop.driverInteractive` | Disposable | Manual     |

The public VM surface is one recipe backed by `scripts/e2e-vm.sh`. The default
and `--show` modes run the same script and assertions; `--show` adds a QEMU
window and short visual holds. `--no-test` explicitly selects a persistent
exploratory VM, implies a visible display, and accepts `--host` (defaulting to
the current hostname). None of these modes is part of `just check`.

The manual interactive-driver entry point is intentionally not another recipe:

```bash
drv="$(nix build .#test-desktop.driverInteractive --no-link --print-out-paths)"
"$drv/bin/nixos-test-driver" --log-level warning
```

Run it from a graphical session, or export the session's `XDG_RUNTIME_DIR` and
`WAYLAND_DISPLAY` first.

## Approach

The regression suite imports the real gauss modules plus `modules/vm-layer.nix`
and test-only instrumentation. QEMU injects physical keys at the guest's virtio
keyboard. The guest's real keyd, compositor, application mapper, and application
then handle them. Each assertion observes the resulting behavior rather than
treating successful input injection as a pass.

There is no universal desktop assertion API. The harness therefore has a small
general core—VM lifecycle, input injection, waiting, reporting—and explicit
adapters at behavioral boundaries:

- Ghostty runs a test-only terminal-protocol peer. PTY input and standard
  terminal-title escape sequences expose focus, tab, window, and paste results;
  Wayland clipboard contents prove copy and paste.
- GTK exposes top-level window titles through AT-SPI. The suite compares the
  complete set of fixture-owned titles rather than scraping pixels.
- GNOME exposes session readiness, overview, and lock state through systemd and
  D-Bus interfaces.

Every default and `--show` invocation executes the driver directly and boots a
fresh disposable VM; Nix may cache the built closure, but not the test
execution. The report records wall time around the driver process because the
native driver's JUnit logger does not record per-subtest durations.

The VM layer autologs in and assigns `daniel` the published fixture password
`secret`. The same password works in all three `e2e-vm` modes. It never enters a
real host configuration.

## What It Verifies

The current suite checks declared dotfiles, the patched GNOME extension, keyd's
application mapper, production Ghostty and GNOME bindings, Ghostty
copy/paste/tab/window behavior, and the complete GNOME lock/authenticate/unlock
cycle.

It can establish that a declared desktop configuration reaches a usable session
and that these specific behaviors work. It does not establish that arbitrary
applications or another compositor work without their own behavioral adapters.

## Tradeoffs

The strongest fact in favor of this design is that it currently works: the
headless and visible paths have repeatedly booted fresh VMs, the negative
control failed, and all twelve current assertions pass.

The design is also intentionally narrow and somewhat brittle:

- Ghostty and GNOME each require custom observation code. Replacing either may
  require replacing its adapter, even when VM lifecycle and input injection
  remain unchanged.
- AT-SPI titles, application protocols, GNOME D-Bus interfaces, and compositor
  readiness units are better boundaries than pixels or timing delays, but they
  are still external contracts that upstream changes can break.
- The suite is isolated from the host, not between subtests. All subtests share
  one boot, session, clipboard, and application state. Order matters, a failure
  may affect later scenarios, and every scenario must assert its preconditions.
- One VM per subtest would provide stronger isolation and cleaner attribution at
  substantially greater setup complexity and runtime. For a handful of stable
  end-to-end scenarios, the current suite accepts shared state and uses
  destruction of the whole VM as teardown.

This is a tested path through two applications, not a general Linux desktop
automation framework. A new application needs an observable consequence for each
action; a new compositor needs replacements for the GNOME-specific readiness,
conflict, focus, and lock boundaries.

## Fidelity Boundary

Keyboard actions are injected at the guest's virtio keyboard. This bypasses the
host's input remapping and exercises the guest's own keyd, compositor, and
application stack. Typing into a headed VM on a host that also runs keyd would
compose the host and guest remaps and is not a faithful test.

The workbench does not verify the host's physical keyboard path, GPU behavior,
display quality, suspend, bootloader, disks, or filesystems from
`hardware-configuration.nix`. It can reject a broken compositor configuration,
but responsiveness, animation quality, and daily-use feel still require real
hardware.
