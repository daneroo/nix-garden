# Install the OS in a VM window on hardy

Status: complete — harvested into [omarchy-vm](../../docs/omarchy-vm.md)

## Closed out

The prototype succeeded and has been turned into a checked-in tool. Nothing
further should be added to this file.

- **The durable document is [docs/omarchy-vm.md](../../docs/omarchy-vm.md).**
  Read that, not this.
- The tool is `scripts/omarchy-vm.sh`, run as `just omarchy-vm`.
- Proven on `hardy` on 2026-09-17: Omarchy 4.0.4 downloaded, hash-verified,
  installed in 2m15s, and booted from its own disk, accelerated with virgl and
  with the keyboard captured.

What this file still offers is the reasoning behind the answers — why Incus and
then libvirt were rejected, why `hardy` is not made non-graphical, and why the
criterion turned out to be input fidelity rather than rendering speed. It is a
log of that search, which is why it is too verbose to work from.

Its disposition is Daniel's to choose: it can stay as the record of how the
conclusions were reached, or be archived under `plans/archive/`.

## The actual end state

`hardy` becomes a **base layer** — a hypervisor-ish host running Incus, Docker,
and whatever else supports the desktops above it. It is not stripped to a bare
non-graphical server, and it is not itself the desktop.

**Desktop OSes run as guests on that base layer**, each getting whatever it
needs to be a genuinely usable desktop.

### The criterion is the keyboard, not the GPU

The thing being fixed is input fidelity. No more keys silently swallowed because
they crossed some intermediate channel — every key and every mapping reaching
the guest desktop intact.

Graphics need to be _functional and accelerated enough to use_. That is all.
This is not a chase for framerate, and no decision here should be argued on
rendering performance.

This also reframes GPU passthrough: its value is a **direct input and display
path**, not speed. Indirection layers — remote display protocols, nested
compositors — are exactly what eat keystrokes. That is the case against them,
and it is the real reason SPICE was the wrong answer earlier.

The existing keybindings E2E suite is the natural acceptance test for any guest
desktop, and should be pointed at them.

### Omarchy Quattro

Quattro has knocked it out of the park and clears the bar. It is therefore both
a **candidate desktop guest in its own right** and the **quality benchmark** to
aim at while building out an equivalent desktop of Daniel's own. It is not
merely a thing being tested — it is the standard.

## What this plan does, and only this

Install Omarchy into a VM, viewed in a window on hardy's **current** desktop.

Performance in this window does not matter and is not a criterion. This is an
installer running once, not a desktop anyone has to live in. Software rendering,
slow redraw, and ugly animations are all acceptable outcomes here. The window is
a temporary viewing port for the install and is thrown away; the only durable
output is the installed disk and an ordinary VM definition.

## Target OSes

Omarchy, and a nested NixOS. Both eventually run one at a time on the passed
-through GPU.

The nested-NixOS side is effectively already served by `just e2e-vm --no-test`,
which runs hardy's own config in a persistent windowed VM. If Daniel wants an
_independent_ NixOS rather than hardy's configuration in a box, that is a
separate flake configuration or an ISO install, and it should be decided before
any work starts — not discovered halfway through.

That leaves **Omarchy as the only real target of this plan**. There is no value
in installing NixOS from an ISO first as a warm-up: the windowed-VM mechanism it
would prove is already proven by the E2E suite.

## Already proven — do not re-test

`just e2e-vm --no-test --host hardy` opens a visible, persistent VM running
hardy's own config. It is the existing keybindings E2E suite and it is used
routinely. So QEMU booting a NixOS VM in a window on hardy, with a GNOME session
inside it and a persistent qcow2 disk, is **established fact**. It is not a step
in this plan and must not be re-litigated as one.

`libvirt` is a manager over that same QEMU, so bringing it up is plumbing rather
than a gamble.

What is genuinely unproven, and all this plan is about:

1. A **foreign** ISO — Arch-based Omarchy, running Hyprland — booting and
   installing in that window. Nothing about it is covered by the NixOS path.
2. GPU passthrough. Deferred to its own plan.

## Mechanism

**Plain QEMU, invoked directly — the same way the E2E suite already does it.**
No libvirt, no virt-manager, and therefore no changes to `hardy` at all.

`result-hardy/bin/run-hardy-vm` runs `qemu-system-x86_64` with `virtio-keyboard`
and `usb-tablet` in QEMU's own native GTK window. Input goes GTK → QEMU →
virtio-keyboard → guest. One hop.

libvirt was proposed here and then rejected. libvirtd spawns that same QEMU, but
virt-manager shows it over **SPICE or VNC** — its window is a SPICE client
talking to a server inside QEMU. That is an extra input indirection,
reintroducing exactly the layer Daniel rejected, and on the keyboard criterion
it is strictly worse than what the E2E suite already does. Recommending it while
claiming the criterion was input fidelity was inconsistent.

What libvirt would have bought — persistent XML, storage pools, a documented
`<hostdev>` passthrough path — is not needed to install an OS once. Raw QEMU
does passthrough too (`-device vfio-pci,host=…`). That choice gets made when
passthrough is the actual subject, not pre-committed now.

Design constraint that still holds: an ordinary persistent qcow2 disk, so the
installed system survives into the passthrough step whichever manager is chosen
then.

## Steps

- [ ] Nothing to install on `hardy`. QEMU comes from the flake/store, exactly as
      the E2E suite gets it. No config change, no apply, no reboot.
- [ ] Obtain and verify the install ISO, pinned below.
- [ ] Create a VM in `virt-manager`: ordinary qcow2 disk, ISO attached.
- [ ] Install through the OS's own normal interactive installer, in the window.
      No unattended install, no cidata drive, no hand-written config, no chroot
      surgery. If the real installer needs any of that, stop and report.

The ISO this plan was proven against:

```txt
version  Omarchy 4.0.1 ("Quattro")
url      https://iso.omarchy.org/omarchy-4.0.1.iso
sha256   69cbb4e10d98ad831c3c9f245b5757a9d1fedfd0c9592780e977d6f950dea8c3
size     6227752960 bytes
built    2026-08-25
```

The URL is versioned and moves as Omarchy releases; the sha256 is the durable
pin, published at the same URL plus `.sha256`. Always check the hash before
booting an ISO — a truncated or stale image fails in ways that look like
installer bugs, and chasing one of those is exactly the sort of blind alley this
plan exists to avoid.

## Result so far — 2026-08-28

Verified on `hardy`, headless, with no changes to the host:

- The ISO boots under OVMF/UEFI in plain QEMU and shows Omarchy's splash.
- `sendkey ret` through the QEMU monitor is accepted, and the **real interactive
  installer starts** — it reaches "Let's setup your machine…" and the
  keyboard-layout list.
- So keyboard input reaches the guest, and `virtio-vga` renders correctly.

Screens were captured with QEMU monitor `screendump`, which needs no display on
the host. That is a useful technique for this whole line of work: progress can
be confirmed from a tty without a graphical session.

The remaining unknown is the rest of the install and the first boot off the
virtual disk.

## Hardware finding — the passthrough step has a conflict

`hardy` is an **ASUS Chromebook Flip C436** (Google "Helios", Hatch platform),
Intel i5-10210U, 8 threads, 15 GiB RAM.

Observed 2026-08-28:

```txt
display controllers   0000:00:02.0  Intel 8086:9b41 (UHD, Comet Lake) -- the only one
IOMMU groups          0
intel_iommu           not in kernel cmdline
```

**There is exactly one GPU and it is integrated.** Passing it to a guest takes
hardy's own display with it, which is the "make hardy non-graphical" outcome
that was explicitly rejected. Both cannot hold on this machine.

This must be decided before any passthrough work begins. Options, none
investigated yet:

- Accept that hardy has no local display while a desktop guest is running.
- Mediated/split GPU (Intel GVT-g, SR-IOV) — likely unavailable: GVT-g is
  effectively gone from modern kernels, and Intel iGPU SR-IOV starts at 12th
  gen. This is 10th gen. **Verify before relying on it.**
- Skip GPU passthrough entirely and use `virtio-gpu` with virgl for "functional
  and accelerated enough", which keeps hardy's display.

Note also that the stated criterion is **keyboard fidelity**, and that does not
actually require GPU passthrough. QEMU's `-object input-linux` feeds raw evdev
from a host input device straight to the guest, bypassing the GTK translation
hop entirely. That may serve the real goal without touching the GPU at all.
Worth evaluating first, since it is far cheaper than passthrough.

## Result: install succeeded — 2026-08-28

Omarchy 4.0.1 installed from the real interactive installer, in a plain QEMU GTK
window, in **2 minutes 0 seconds** on the Chromebook's 15W mobile i5. The qcow2
went from 198 KiB to 5.9 GiB.

One operational gotcha worth keeping: QEMU GTK's **"Zoom to Fit" must be OFF**.
With it on, a small guest framebuffer is scaled up to the window — bigger,
blurrier, and exactly the same number of text rows, which made the installer's
timezone list impossible to read at 640x480. With it off, resizing the window
resizes the guest.

## Result: acceptance test PASSED — 2026-08-28

Omarchy 4.0.1 installed, rebooted off its own encrypted virtual disk (LUKS
prompt, then desktop), and was used interactively. Disk 198 KiB → 7.6 GiB.

### The two things that made it good

**Acceleration — `virtio-vga-gl` + `gl=on`.** Confirmed real, not just enabled:
guest `GL_RENDERER` reports **virgl (Mesa)**, and `glmark2` scores **773**.
Software rendering on this chip would be in the low hundreds. Host comparison
number still outstanding.

**Keyboard capture — `-object input-linux`.** This was the breakthrough, and
Daniel's verdict was "more than usable". Grab the **keyd virtual keyboard**
(`/dev/input/event8`), never the physical `event0` — keyd already holds an
exclusive grab on event0, and taking keyd's _output_ means its remappings still
apply inside the guest while the host compositor sees nothing. That is what
stops host bindings like `super-space` being stolen before the guest sees them.
Toggle with both Ctrl keys.

Notably, this mattered more than acceleration did. The desktop was already "more
than usable" with pure software rendering once input was fixed — latency, not
pixels, was the real problem. That supports skipping GPU passthrough entirely on
this hardware.

### Operational gotchas, all hit for real

- **`screendump` does not work with `gl=on`.** The scanout becomes a dmabuf in
  GPU memory rather than a QEMU-side surface, so captures silently produce no
  file. Headless visibility into the guest is lost the moment GL is enabled.
- **Keyboard grab makes the host lock itself out.** With input grabbed, GNOME
  sees no activity, its idle timer fires, and the resulting lock screen _cannot
  be typed into_ because QEMU holds the keyboard. `run.sh` now wraps QEMU in
  `systemd-inhibit --what=idle:sleep`. Escape hatch if it happens:
  `loginctl unlock-session <id>` works from any shell, no keyboard needed.
- **Fullscreen + grab hides the window that owns your input.** Leave fullscreen
  off while `RAWKB=1`, or remember `Ctrl+Alt+F`.
- **Never run `glmark2-gbm` on a host with a live session.** It does a DRM
  modeset and fights the compositor for the display. Benchmark the host from
  inside its own graphical session instead.
- **"Zoom to Fit" must be OFF**, or the guest never resizes past 640x480.
- `system_powerdown` on the QEMU monitor shuts the guest down cleanly; allow it
  up to a minute.

### What this implies for the destination

Option 3 — accelerated `virtio-gpu` plus raw input capture — looks like it may
be the whole answer, with no GPU passthrough, no IOMMU, no VFIO, and no coreboot
reset risk, and hardy keeps its own display. That should be proven or disproven
before any passthrough plan is written.

## Reference numbers — 2026-08-28

`glmark2 2023.01`, 800x600 windowed, GLX via XWayland on both sides.

|                        | Score    | % of native | Renderer                          |
| ---------------------- | -------- | ----------- | --------------------------------- |
| `hardy` host           | **4010** | —           | Mesa Intel UHD Graphics (CML GT2) |
| Omarchy guest, 4 cores | 773      | 19.3%       | virgl (Mesa)                      |
| Omarchy guest, 8 cores | **1026** | 25.6%       | virgl (Mesa)                      |

Doubling the guest's cores bought **+33%**, so the guest was genuinely CPU
starved — virgl does heavy CPU-side translation in the guest's Mesa. But 2x the
cores yielding only 1.33x the score means cores are not the real bottleneck:
**virgl's overhead dominates**, and the gap closes from 5.2x to 3.9x and no
further on this chip.

Practical setting: **`SMP=6`**. Most of that gain arrives with the first extra
cores, and it leaves the host usable rather than sluggish.

None of this changed the verdict. The desktop was judged "more than usable"
before acceleration was enabled at all.

## The remaining practical problem: grab and release

Acceleration is settled enough. What is actually awkward in daily use is
capturing and releasing the keyboard.

Current behaviour: both Ctrl keys toggle capture, with **no visual feedback** in
either direction, and while captured the host cannot be typed into at all.

**Likely interaction with PaperWM.** `hardy` runs PaperWM tiling
(`hosts/hardy/default.nix:136`), a niri-like scrollable tiling model. A
fullscreen QEMU window can end up scrolled outside the visible viewport — and
with the keyboard captured, there is no way to scroll back to it. That fits the
observed "the window is running but I cannot find it" exactly, better than the
window being genuinely lost. **Unverified — test before believing it.**

Directions worth trying, cheapest first:

- Run the VM **windowed rather than fullscreen** while captured, so it stays
  findable.
- Put the QEMU window in PaperWM's scratch/floating layer so it is not part of
  the scrollable strip at all.
- Find out whether the capture toggle can be rebound to something less awkward,
  and whether any on-screen indication is possible.

## `gauss` is the better host for this

|         | `hardy`                             | `gauss`                        |
| ------- | ----------------------------------- | ------------------------------ |
| CPU     | i5-10210U, 8 threads                | Ryzen 7 8845HS, **16 threads** |
| GPU     | Intel UHD 620 (CML GT2)             | **Radeon 780M** (RDNA3)        |
| Chassis | ASUS Chromebook Flip C436, coreboot | Beelink SER8                   |

The 780M is in a different class from UHD 620, and 16 threads means a guest can
have 8 without starving the host — the exact constraint that likely capped the
guest at 19%. Everything proven here should transfer, and the whole exercise is
worth redoing on `gauss` where the headroom actually exists.

## Acceptance test

Daniel is at `hardy` and watches the OS install through its real installer in a
window, then sees the installed system **boot from its own virtual disk** to its
desktop in that window, with working keyboard and mouse.

Then stop and report. Do not continue to the next step.

## Deferred, each its own plan, in this order

1. Pass the real GPU through to this same VM, for a direct input and display
   path.
2. Point the keybindings E2E suite at the guest desktop and prove every key and
   mapping arrives intact.
3. Build out `hardy` as the base layer proper — Incus, Docker, and the
   supporting pieces alongside libvirt.

**Not** making `hardy` non-graphical. That was proposed and explicitly rejected:
hardy is a base layer, not a stripped server. 3. Additional distros, one at a
time.

Nothing from that list gets touched, researched, or prepared for during this
plan, beyond the disk-and-definition constraint noted above.

## Fallback ladder

Daniel's standing instruction: if we hit a wall, drop to something simpler
rather than grinding on it. Descending this ladder is a success, not a defeat,
and does not need a new round of approval — report the wall and the move.

1. `libvirt` + `virt-manager` — current choice.
2. **GNOME Boxes** — point it at an ISO and click. Same libvirt/QEMU underneath,
   almost no configuration surface to get wrong.
3. **quickemu** — one command, no daemon, no libvirt at all.

All three are packaged in nixpkgs and available on hardy. If all three fail to
put an installer in a window, that is a hardware or host finding worth reporting
on its own, and the project should stop there rather than continue.

## Artifacts outside the repository — MUST be cleaned up

This plan creates large files that git does not track and that no branch
deletion will remove. **If this branch is abandoned or never merged, these
survive silently and waste disk.** Whoever drops the branch must also run the
cleanup below.

| Path                                     | Size          | Notes                                   |
| ---------------------------------------- | ------------- | --------------------------------------- |
| `/home/daniel/isos/omarchy-4.0.1.iso`    | 5.8 GiB       | Re-downloadable; pinned by sha256 above |
| `/home/daniel/isos/.curl.log`            | tiny          | Download log                            |
| `/home/daniel/vms/omarchy/omarchy.qcow2` | up to 120 GiB | Sparse; grows as the install proceeds   |
| `/home/daniel/vms/omarchy/OVMF_VARS.fd`  | 528 KiB       | Per-VM UEFI nvram                       |
| `/home/daniel/vms/omarchy/qemu.log`      | tiny          |                                         |
| `/home/daniel/vms/omarchy/*.png`         | small         | Monitor screenshots                     |

A long-lived `qemu-system-x86_64` process may also be running and holding the
disk open. Stop it first.

```sh
pkill -f 'qemu-system-x86_64.*omarchy' || true
rm -rf /home/daniel/vms/omarchy
rm -rf /home/daniel/isos          # only if the ISO is not wanted for a retry
```

Keeping the ISO is reasonable between attempts; keeping a stale qcow2 is not,
because a half-finished install is exactly the kind of unverified state this
plan exists to avoid inheriting.

## Stop conditions

- Any step fails twice — stop and report what was observed.
- The install is not done within an hour — stop and report.
- A step appears to need a workaround, a manual boot edit, or a hand-written
  config file — stop and report rather than working around it.
