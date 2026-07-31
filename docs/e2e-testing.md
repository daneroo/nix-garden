# End-to-End (E2E) Testing

## Live Desktop Suite

Run the fast behavioral suite from a visible Ghostty terminal in the local GNOME
session:

```bash
./scripts/e2e.sh
./scripts/e2e.sh -y
./scripts/e2e.sh -y --slow 2
```

The command takes control of the current workspace, overwrites the clipboard,
and requests attended sudo access for bounded `keyd monitor` evidence. It
captures and restores the focused window, plain-text or empty clipboard,
temporary accessibility setting, fixture processes, and profiles. Rich clipboard
formats cannot be restored. `--slow` pauses at labelled visual checkpoints and
holds failures open briefly for inspection.

Run it directly beneath the visible Ghostty process. The Brave scenario refuses
a Herdr-rooted or otherwise detached lineage because GNOME will not grant a
terminal-launched native Wayland window the same activation eligibility. Do not
type, switch workspaces, or run a second copy while the suite controls the
desktop.

The Bun project root is `tests/e2e/bun/`; its private manifest owns the source
test command. The suite injects physical chords through ydotool before keyd,
retains keyd input or mapped-output evidence, and observes fixture behavior
through terminal protocol, AT-SPI, and Brave DevTools. Brave clipboard setup
stays inside the focused fixture page: launching `wl-copy` or `wl-paste` between
application-mapped chords changes GNOME's reported active client and causes
`keyd-application-mapper` to reset the Brave bindings.

The live suite covers Ghostty lifecycle, tabs, selection, clipboard, native
Control-C, and unbound Alt input, plus Brave lifecycle, tabs, address
navigation, tab selection, and clipboard translation. It is intentionally not
part of `just check`. Gauss passed the complete guarded suite on 2026-07-29;
Hardy validation and VM consolidation remain follow-up work.

## VM Workbench

The desktop workbench boots a selected host's declared configuration in a VM.
The same VM-only layer supports unattended regression, visible demonstration,
and hands-on exploration without changing a real host.

## Modes

| Mode                  | Command                                          | State      | Assertions |
| --------------------- | ------------------------------------------------ | ---------- | ---------- |
| Headless regression   | `just e2e-vm [--host HOST]`                      | Disposable | Yes        |
| Visible regression    | `just e2e-vm --show [--host HOST]`               | Disposable | Yes        |
| Headed exploration    | `just e2e-vm --no-test [--host HOST]`            | Persistent | No         |
| Interactive authoring | Build and run a host-specific interactive driver | Disposable | Manual     |

On Hardy or Gauss, omitting `--host` selects the current hostname. An explicit
`--host hardy` or `--host gauss` runs the same contract against the other host's
configuration. Galois is not a NixOS test executor; coordinate the command on a
managed host instead.

The public surface is one recipe backed by `scripts/e2e-vm.sh`. Default and
`--show` modes invoke the same script and assertions; `--show` adds a QEMU
window. `--no-test` opens a persistent exploratory VM and implies a visible
display. None of these modes is part of `just check`.

The manual interactive-driver entry point remains available:

```bash
drv="$(
  nix build .#test-desktop-HOST.driverInteractive \
    --no-link \
    --print-out-paths
)"
"$drv/bin/nixos-test-driver" --log-level warning
```

Replace `HOST` with `hardy` or `gauss`. Run it from a graphical session, or
export that session's `XDG_RUNTIME_DIR` and `WAYLAND_DISPLAY` first.

## Approach

Each test output imports the selected real host modules plus
`modules/vm-layer.nix` and test-only instrumentation. QEMU injects physical keys
at the guest's Virtio keyboard. The guest's real keyd, compositor, focused
application mapper, and applications then handle them.

There is no universal desktop assertion API. The harness keeps a small common
core—VM lifecycle, physical input injection, waiting, and reporting—and uses
explicit adapters at behavioral boundaries:

- A test-only GTK/GDK probe records the logical modifier mask delivered for
  physical Alt, Ctrl, and Super input.
- Ghostty runs a terminal-protocol peer. PTY bytes and standard terminal-title
  escape sequences expose focus, tabs, windows, paste, Control-C, and unbound
  terminal Alt input; Wayland clipboard contents prove copy and paste.
- Brave opens deterministic pages from a guest-local HTTP server. Clipboard
  contents, its local debugging page list, and AT-SPI frame titles/counts expose
  copy, paste, tab navigation, close/reopen, new windows, and address focus.
- GNOME exposes declared settings, session readiness, overview state, and
  screensaver state through gsettings, systemd, and D-Bus.

Hardy's real keyd declaration intentionally matches only its internal Chromebook
keyboard. The test layer adds an identity-preserving declaration for the VM
keyboard so Brave's composite Alt+Shift mappings are exercised without weakening
production device scope or simulating the illumination adapter.

Every default and `--show` invocation executes the driver directly and boots a
fresh disposable VM. Nix may cache the closure, but not test execution. The
report records wall time around the driver because the native JUnit logger does
not record per-subtest durations.

The VM layer autologs in and assigns `daniel` the published fixture password
`secret`. It never enters a real host configuration.

## Third-Party Keybinding Overrides

The suite asserts what this repository declares, not GNOME's upstream defaults.
A binding a GNOME extension legitimately claims is out of scope, and asserting a
stock value makes the suite fail on any extension or GNOME bump.

PaperWM is the live example. Its `enable()` path calls `overrideConflicts()`,
which blanks every conflicting key in `org.gnome.shell.keybindings`,
`org.gnome.desktop.wm.keybindings`, and the two Mutter keybinding schemas -- the
whole key, not just the colliding accelerator -- and restores them from
`restore-keybinds` on disable. Both hosts enable PaperWM, so it owns `Super+N`
(`new-window`), `Super+V` (`center-vertically`, which takes the message tray's
`Super+M` as collateral), and `Super+Tab` plus `Alt+Tab` (`live-alt-tab`).

Three stock-default assertions in `tests/desktop.py` are commented out for that
reason, with the detail recorded there. Assertions that check keys this
repository sets (Alt+Space, the three custom keybindings, the screenshot pair)
are unaffected and stay.

## Evidence Classes

The 27-case suite deliberately distinguishes three kinds of evidence.

### Semantic assertions

These cases observe the intended consequence:

- exact, distinct Alt, Ctrl, and Super delivery;
- no declared base Alt-to-Super carrier;
- store-backed configuration, extension, and mapper health;
- the complete declared Ghostty, Brave, and GNOME maps;
- Ghostty copy/paste/tab/window/navigation behavior;
- native terminal Ctrl+C and unbound Alt+D input;
- Brave copy/paste, native Ctrl preservation, tab/window/navigation behavior,
  address focus, close, and reopen;
- the unlocked-session precondition and survival after logout-dialog
  cancellation.

The old Gauss carrier supplied the negative control: the target modifier case
failed before implementation because physical Alt arrived as `SUPER+MOD4`.

### Guided passes

Some actions have no proportional stable semantic boundary. The suite performs
the same action and four-second pause in headless and visible modes, reports the
subtest as passing, and does not claim that the visual consequence was asserted:

- Ghostty Alt+K clear screen;
- Brave Alt+F find surface;
- GNOME Alt+Shift+L lock;
- GNOME Alt+Shift+Q logout confirmation.

The lock case additionally records the exact keyd input events and restores an
unlocked session. The logout case sends Escape and asserts that the graphical
session survived.

On real Gauss, both session actions work. In a visible Gauss VM, neither the
lock nor logout consequence appeared despite correct injection and a passing
guided subtest. That non-blocking fidelity bug is tracked in
[visible-vm-session-actions](../thoughts/tickets/visible-vm-session-actions.md);
passing guided cases must not be described as semantic proof.

### Hardware-only evidence

The suite does not assert screenshots. Headless GNOME produced no screenshot
file for either the target chord or an unchanged Shift+Print positive control,
and Shell restricts its screenshot D-Bus methods to trusted desktop callers.
Alt+Shift+3 was therefore accepted by observing a newly created file on each
real host.

The VM also cannot prove a host's physical keyboard path, Hardy's device-scoped
illumination, external-keyboard behavior, authenticated 1Password/Brave state,
GPU/display quality, suspend, bootloader, disks, or daily-use feel.

## Current Coverage

The most recent runs on 2026-07-30 passed:

- Hardy: 27/27, 96.3 seconds wall time.
- Gauss: 27/27, 73.8 seconds wall time.

Real-hardware passes separately established the complete shared application and
desktop map, Files as the unnamed-application negative control, 1Password,
logout/login, and reboot persistence. Hardy's external-keyboard comparison is
the remaining explicit hardware follow-up.

## Tradeoffs

The suite is isolated from the host, not between subtests. All cases share one
boot, session, clipboard, and application state. Order matters, a failure may
affect later scenarios, and each case must assert its preconditions. One VM per
subtest would improve isolation at substantially greater setup and runtime cost.

Application behavior needs application-specific observation. Ghostty's custom
renderer, Chromium's process model, GNOME Shell modals, and screenshot security
boundaries each require different evidence. Stable semantic boundaries are
preferred, but guided or hardware-only acceptance is better than an
unmaintainable framework or a false automated claim.

This is a tested path through Ghostty, Brave, and GNOME, not a general desktop
automation framework. A new application needs a named behavior and a
proportional observable consequence.

## Fidelity Boundary

Keyboard actions are injected at the guest's Virtio keyboard. This bypasses host
input remapping and exercises only the guest configuration. Typing into a headed
VM on a host that also runs keyd composes the host and guest input paths and is
not a faithful measurement.

The modifier probe and no-carrier invariant prove the guest's logical model.
Real-hardware acceptance remains authoritative for physical device identity,
focus behavior in authenticated applications, and session actions that GNOME
does not reproduce faithfully in the VM.
