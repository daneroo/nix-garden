# Desktop VM Fidelity — When Is Remote/Virtual Good Enough?

Research note, 2026-07-12, supporting `desktop-test-harness` and
`compositor-selection`. Question: can Daniel judge keybinding and desktop UX
through VNC or a VM, given that VNC/RustDesk to Proxmox VMs has felt too
unrealistic to trust?

## Answer

No single channel does both jobs. Split the harness by what is being judged:

- **Functional validation** — "did Super+Enter spawn a terminal?" Agents, the
  NixOS test driver, OCR, and VNC are all adequate. Latency and feel do not
  matter for a boolean.
- **Experiential judgment** — feel, latency, animation smoothness, whether a
  binding lands in muscle memory. This needs real hardware or near-metal setups.
  VNC is structurally disqualified, not just inconvenient.

The Proxmox VNC experience was diagnostic, not user error. Three stacked causes:

1. **Protocol.** RFB (VNC) transmits keysyms, not scancodes; the
   keysym-to-scancode reversal is lossy and layout-dependent. QEMU added a
   scancode extension that modern clients (noVNC, TigerVNC, GTK-VNC
   /virt-viewer) support, so raw key delivery is fixable — but only with a
   compatible client and no `-k` keymap forced.
2. **Modifier capture.** The host OS and browser eat exactly the keys under
   test: Cmd/Super shortcuts go to macOS or to the browser tab hosting noVNC
   (Cmd+W closes the console, not the guest window).
3. **Frame path.** Framebuffer polling, no GPU acceleration, no frame pacing.
   Any judgment about Niri's scrolling model or animation smoothness through VNC
   is judgment about VNC.

## Fidelity Ladder

From fastest iteration to highest fidelity; each rung has a distinct use.

### L0 — Nested compositor (seconds per iteration)

Niri and Hyprland both run as a window inside an existing Wayland/X session.
Perfect for config syntax, layout behavior, and rapid binding edits. The parent
compositor shadows some modifiers, so not for final binding judgment.

### L1 — Local QEMU with virtio-gpu (the agent tier)

`nixos-rebuild build-vm` plus `virtio-gpu-gl` and a local SDL/GTK QEMU display.
The GTK display grabs all input on demand (Ctrl+Alt+G), delivering raw scancodes
including Super; virgl gives the guest accelerated OpenGL. Good enough to see a
compositor behave and to host agent computer-use and `driverInteractive`
sessions. Still not "feel": frame pacing and input latency remain visibly
virtual.

### L2 — Specialisations on real hardware (the UX judgment tier)

NixOS `specialisation` builds Niri and Hyprland as additional boot entries on
top of the base config. Select at the boot menu, or activate from the running
system via the activation script under `/run/current-system/specialisation/`.
Real GPU, real input path, zero virtualization artifacts, rollback by rebooting.
This — not virtualization — is the right instrument for "does this binding feel
right", and it needs no new machines: `hardy` or `gauss` today. Running the
candidate compositor on a second VT is the same idea with less isolation.

### L3 — Dedicated bake-off metal

`gauss` reinstalled via nixos-anywhere as a disposable desktop target, for
week-long daily-use trials per compositor, per the design doc's
evidence-before-abstraction rule.

### Sidebar — fullscreen VM on `galois` (M2)

Mitchell Hashimoto famously daily-drives NixOS as a fullscreen VMware Fusion/UTM
VM on macOS ([mitchellh/nixos-config]). Fullscreen capture sends Cmd to the
guest, graphics are accelerated, and the workflow is proven for development. It
is a legitimate mid-fidelity desktop testbed on the Mac — while remembering the
goal is judging a Linux-native experience, and an aarch64 guest under a macOS
compositor is still one abstraction away from `hardy`'s metal.

## Objective Instruments

Turn "feels wrong" into data before debating it:

- `wev` (Wayland) / `xev` (X11) — show exactly which keysyms/modifiers the guest
  compositor receives.
- `keyd monitor` — observe remaps at the evdev level, no GUI needed.
- `libinput debug-events` — the kernel-input ground truth.

A useful drill: run `wev` inside the VM through each channel (VNC, SPICE, local
SDL) and press the contested chords. Where the events differ from a local
keyboard, that channel is disqualified for binding tests — measured, not vibed.

## The macOS-on-QEMU Demo

The demo seen was almost certainly [OSX-KVM] via its Nix flake wrappers
([ngi-nix/OSX-KVM], `onny/OSX-KVM` flake branch): `nix run` boots an OpenCore
QEMU VM and installs macOS from Apple's recovery images. It is a nice proof of
how far declarative QEMU plumbing goes (and a possible future keybinding
reference target), with the usual Apple-EULA caveat that macOS licensing permits
virtualization only on Apple hardware.

## Implications for the Harness

- Agent/CI validation: L1 VM + NixOS test driver + OCR; VNC acceptable here.
- Human binding iteration: L0 nested for edits; L2 specialisations for judgment.
- Compositor decision: L3 daily use, one week each, per existing backlog.
- Never conclude anything about feel through a remote framebuffer.

## Sources

- [Berrangé: virtual keyboard handling](https://www.berrange.com/posts/2010/07/04/more-than-you-or-i-ever-wanted-to-know-about-virtual-keyboard-handling/)
- [noVNC and the QEMU RFB scancode extension](https://danielhb.github.io/article/2019/05/06/noVNC-QEMU-RFB.html)
- [Tweag: introduction to NixOS specialisations](https://www.tweag.io/blog/2022-08-18-nixos-specialisations/)
- [mitchellh/nixos-config]
- [NixOS wiki: OSX-KVM](https://wiki.nixos.org/wiki/OSX-KVM)

[mitchellh/nixos-config]: https://github.com/mitchellh/nixos-config
[OSX-KVM]: https://github.com/kholia/OSX-KVM
[ngi-nix/OSX-KVM]: https://github.com/ngi-nix/OSX-KVM
