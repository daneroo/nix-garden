# Omarchy VM

Runs Omarchy as a guest in a window, with the keyboard genuinely reaching the
guest. Opt-in: it changes no NixOS configuration and installs nothing on the
host, taking QEMU and OVMF from the flake's locked `nixpkgs` at runtime.

Plain QEMU in a GTK window. libvirt was rejected because `virt-manager`'s window
is a SPICE client, adding a protocol hop on the one path that matters here:
keyboard input.

Commands, flags, variables and defaults are in `just omarchy-vm --help`, beside
the code that reads them. This document covers only what the help text cannot:
why it is built this way, and what has already gone wrong.

## Files

Everything lives outside the repository; Git tracks none of it.

| Path                               | What                                |
| ---------------------------------- | ----------------------------------- |
| `~/vms/omarchy/omarchy.qcow2`      | the guest disk; the valuable thing  |
| `~/vms/omarchy/OVMF_VARS.fd`       | per-VM UEFI variables, boot entries |
| `~/vms/omarchy/omarchy-vm.pid`     | PID of this VM's QEMU               |
| `~/vms/omarchy/omarchy-vm.monitor` | QEMU monitor socket                 |
| `~/isos/omarchy-<release>.iso`     | installer image                     |

## The ISO pin

Download URLs are versioned and move; the hash identifies the image. A release
becomes usable only once its published SHA-256 and byte size are recorded in
`select_release()` in `scripts/omarchy-vm.sh`. Upstream publishes the hash at
the ISO URL plus `.sha256`.

Downloads land in a `.part` file, renamed only after the hash matches, so an
interrupted transfer cannot be mistaken for a good image. An existing ISO that
fails verification stops the run and is never silently overwritten.

## Keyboard capture

The point of the exercise. Without it, host bindings such as `super-space` are
swallowed by the host compositor and never reach the guest.

`run` hands the guest a raw evdev device via QEMU's `-object input-linux`, which
works below the compositor. Capture toggles with **both Ctrl keys at once**.
While captured the host has no keyboard at all; that is what makes it work.

Capture takes the **keyd virtual keyboard**, never the physical one: keyd holds
an exclusive grab on the physical device and republishes it, so taking keyd's
output keeps its remappings inside the guest while the host sees nothing. The
device is resolved by name and re-checked before use, because event numbers move
between boots. There is deliberately no fallback to a physical keyboard.

Access is needed on that device, for one boot:

```sh
sudo setfacl -m u:$USER:rw /dev/input/event8   # whichever node keyd holds
```

## Shutdown

`stop` sends ACPI power-down through the VM's monitor socket and waits up to 90
seconds. Prefer it; the guest unmounts cleanly.

It cannot work before the guest has an operating system running. A VM sitting at
a LUKS passphrase prompt has no one to receive ACPI, so `stop` waits its full 90
seconds, reports that the guest may be ignoring ACPI, and exits without killing
anything. Use `force-stop` there — nothing is mounted yet, so nothing is at
risk.

`force-stop` validates the recorded PID, confirms the process really is this
VM's QEMU, and signals only that PID — never a pattern kill, which would take
unrelated VMs with it. Expect a filesystem check on next boot.

Closing the window is a power cut, not a shutdown.

## Gotchas

Each of these cost real time.

- **"Zoom to Fit" must be OFF.** With it on, QEMU scales a small framebuffer up
  to the window: bigger, blurrier, same number of text rows. An installer's
  timezone list stays unreadable at 640x480 however large the window.
- **While captured, `Ctrl+Alt+F` and `Ctrl+Alt+G` do nothing.** Every key goes
  to the guest, so GTK never sees its own shortcuts. Release capture first.
- **Avoid fullscreen while captured.** A scrollable tiling workspace such as
  PaperWM can move the window out of view and you cannot type to get back.
  Recover with `just omarchy-vm stop` from another shell.
- **The host can idle-lock itself out.** With input captured the host sees no
  activity, its idle timer fires, and the lock screen cannot be typed into. The
  VM is wrapped in `systemd-inhibit --what=idle`. If it happens anyway,
  `loginctl unlock-session <id>` needs no keyboard. Idle only, never sleep:
  blocking sleep is gated behind polkit and prompts for a password on every
  launch.
- **`screendump` does not work with `gl=on`.** The scanout becomes a dmabuf in
  GPU memory, and captures silently produce no file. `install` runs without GL,
  so screenshots work there.

## Performance expectations

`glmark2 2023.01`, 800x600 windowed, on `hardy` (i5-10210U, Intel UHD 620):

| Configuration         | Score | Of native |
| --------------------- | ----- | --------- |
| host, direct          | 4010  | —         |
| guest, virgl, 4 cores | 773   | 19%       |
| guest, virgl, 8 cores | 1026  | 26%       |

Doubling cores bought 33%, so virgl overhead dominates rather than CPU. Six
guest cores gets most of that gain while leaving the host usable. Treat these as
expectations, not targets: the desktop was judged more than usable before
acceleration was enabled at all. Input latency mattered far more than rendering
throughput.

## Repeating this on gauss

Host-agnostic; only the numbers should change. `gauss` is a Beelink SER8 with a
Ryzen 7 8845HS and Radeon 780M — 16 threads against hardy's 8, and a much
stronger GPU — so both limits above should ease.

Install and run it the same way. What is worth checking on a new host, because
none of it is guaranteed to carry over: that the guest reports `virgl` as its GL
renderer rather than a software one, that the captured device really is named
`keyd virtual keyboard`, and that keyd's remappings arrive in the guest.

## Cleanup

Not part of normal operation. These files are large and Git tracks none of them,
so deleting a branch will not remove them.

```sh
just omarchy-vm stop            # never delete a running VM's disk
rm -rf ~/vms/omarchy            # the guest, its UEFI variables, its sockets
rm -f ~/isos/omarchy-*.iso      # installer images, about 6 GB each
```

Removing the VM directory destroys the installed guest. Keeping an ISO between
installs is reasonable; keeping a half-finished disk is not.
