# desktop-test-harness — A VM Workbench for Desktop Changes

Priority: high

Make it possible to build a proposed configuration, boot it in a VM, and judge
or verify its desktop behavior without touching `gauss` or `hardy`. This is the
enabler for the two things Daniel actually wants to do next: consolidate the
keybinding model, and try a different compositor.

## Why This Comes First

Both queued desktop objectives currently require mutating a working machine to
learn anything:

- `simplified-keybinding-model` proposes removing the global Alt -> Super swap.
  The validated bindings on both hosts are the thing at risk.
- `compositor-selection` proposes replacing GNOME. There is no way to form an
  opinion about Niri or Hyprland without installing one.

Today the only feedback loop is `just apply` on a real host. A VM built from the
same flake turns both into reversible experiments, which is what makes a
test-first workflow possible at all.

## The Core Idea: One VM Definition, Three Drive Modes

The important realization is that "let me look at it" and "assert it in CI" are
not different systems. They are the same VM driven differently:

| Mode        | Mechanism                          | Used for                                 |
| ----------- | ---------------------------------- | ---------------------------------------- |
| Headed      | `nixos-rebuild build-vm`, QEMU GUI | Exploration; judging a compositor by eye |
| Interactive | `.driverInteractive` Python REPL   | Probing a chord; authoring an assertion  |
| Headless    | `runNixOSTest` under `checks`      | Regression; runs unattended              |

The intended workflow is that exploration in the headed VM produces findings,
the interactive REPL turns a finding into a reproducible sequence, and that
sequence is committed as a headless check. The headless suite is the residue of
the exploration, not a parallel effort.

Constraint to respect: `hardware-configuration.nix` filesystems are ignored in
VM mode. The workbench validates services, packages, users, session, and desktop
configuration — not boot or disk layout. See
[desktop-test-harness-fidelity](../research/desktop-test-harness-fidelity.md)
for the full fidelity ladder; in its terms this ticket builds L1, and L2
specialisations on real hardware remain the instrument for judging feel.

## What a Test Asserts

Injecting a keypress is solved (`ydotool`, and the NixOS driver's `send_key`);
observing the result is not. The harness needs an assertion vocabulary:

| Observable    | Probe                                    |
| ------------- | ---------------------------------------- |
| Clipboard     | `wl-paste` / `wl-copy`                   |
| Window state  | `wmctrl` on GNOME; `niri msg`; `hyprctl` |
| Screen text   | driver `wait_for_text` (OCR)             |
| Widget state  | AT-SPI (`pyatspi`, `accerciser`)         |
| Service state | driver `wait_for_unit` / `succeed`       |

Window-state probing is the only compositor-specific part, which is what lets
the suite survive a GNOME -> Niri migration largely intact.

Structure the suite as a table: chord x application x expected observable,
mirroring the equivalence table in
[docs/keybindings.md](../../docs/keybindings.md). That table is already the
acceptance criterion humans use; making it the test fixture avoids maintaining
two descriptions of the same thing.

## Scope Discipline

Prove the loop on one chord — copy is the obvious candidate, since clipboard
state is trivially observable — before widening to anything else. A harness that
covers one chord end to end is worth more than a framework that covers none.
Widen only after that passes unattended.

## Questions

- Does the GNOME session reach a usable state in `build-vm` without display or
  GPU work? What is the minimum to get a real session rather than a console?
- Is `virtio-gpu-gl` plus a local GTK/SDL display needed for the headed mode to
  deliver raw scancodes including Super, per the fidelity research?
- Can `keyd` and its application mapper run meaningfully inside the VM, or does
  the guest need a different input path? The application mapper depends on a
  patched GNOME Shell extension today.
- Which chords are testable headlessly and which genuinely need a human? Record
  the boundary rather than pretending OCR covers judgment.
- Do the graphical checks belong in `nix flake check` (and therefore
  `just check`), or behind an explicit `nix build .#checks...` and a separate
  `just` recipe? Default assumption: keep slow graphical tests out of the
  default gate.
- Does this want `flake-parts` to express `checks` cleanly across systems, or
  does a plain `checks.<system>` attribute suffice for now? See
  [module-architecture](../research/module-architecture.md); do not adopt
  scaffolding this ticket does not need.
- Is a VM good enough to compare Niri and Hyprland, or only to eliminate one?
  The fidelity research says feel cannot be judged through virtualization.

## Required Outcome

- A repository command that boots any host's configuration in a VM.
- One committed headless check that exercises a real chord end to end and fails
  when the binding is wrong.
- A documented way to drop into the interactive driver against the same VM.
- A stated boundary between what the harness verifies and what still requires
  real hardware.
