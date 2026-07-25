# desktop-test-harness

Status: planned

Goal: build a VM workbench that boots any host's configuration for hands-on
experimentation and can also assert one real keybinding headlessly, so that
keybinding consolidation and compositor experiments become reversible. Working
detail in [desktop-test-harness](../tickets/desktop-test-harness.md).

Stop after the single-chord check passes. Widening the suite is deliberately out
of scope for this plan; it belongs to whichever desktop work runs next.

## Execution and Handoff

Execute on `gauss`, in a session running on `gauss` itself. It is the keybinding
trial host per
[simplified-keybinding-model](../design/simplified-keybinding-model.md), has the
conventional PC keyboard, and has the strongest hardware for VM work. Do not
drive this from `galois`: `just plan`, `just apply`, and
`nixos-rebuild build-vm` all require the target host, and the headed VM needs a
local display.

Two of the three drive modes are text-only, which decides what can be done
remotely:

| Mode                     | Remote over SSH/Herdr?                |
| ------------------------ | ------------------------------------- |
| Headed QEMU              | No — needs a local display on `gauss` |
| `driverInteractive` REPL | Yes                                   |
| Headless `runNixOSTest`  | Yes                                   |

So the build-out and the assertion work can proceed from anywhere. Windows the
work opens still render on `gauss`'s display, and Daniel can switch to it to
observe them — so the executing agent should say explicitly when it has put
something on screen worth looking at, rather than assuming nobody can see it.

Run the agent session under Herdr, not in a plain Ghostty terminal on `gauss`'s
desktop. This work boots VMs and may end the desktop session, and a terminal
living inside that session dies with it. Both applies on 2026-07-25 killed the
GNOME session; the Herdr session survived and reconnected on its own. Herdr also
means the session can be driven from `galois` between the steps that need a
local display.

Git flow, per [workflow.md](../../docs/workflow.md#plans):

- This ticket and plan are committed on `main`.
- On `gauss`: `git pull`, then create the branch `desktop-test-harness`.
- Push the branch so it is reviewable from `galois` without a session on
  `gauss`.
- Keep the checkboxes below current as work proceeds; commit them with the code
  they describe rather than in a separate bookkeeping pass.
- Merge to `main` when the single-chord check passes.

## Prerequisite: Move the Fleet Lock First

Do this before branching, so the harness is built against a lock that will not
move underneath it. `just update` cannot run from `galois`; the `Justfile`
restricts to blessed NixOS hosts and builds only `.#$(hostname)`.

- [x] On `gauss`: `just update`. Review both the `flake.lock` diff and the
      closure diff before accepting. Commit the lock and push. Do not apply yet.
      Done in `105a3e6`: nixpkgs `241313f` -> `e2587ca`, herdr unchanged.
      `[tier: med]`
- [x] On `hardy`: pull, then `just apply`. Hardy is the canary — it takes the
      risk first so that `gauss`, the machine about to run this plan, stays on a
      known-good system until the update is proven. Applied as generation 21;
      the switch ended the GNOME session, and `just apply` skipped verification
      because `nixos-rebuild` exited 4, which is what prompted the recipe fix in
      `84c5ea7`. `[tier: med]`
- [x] On `hardy`: re-verify the acceptance map in
      [docs/keybindings.md](../../docs/keybindings.md). This update turned out
      to leave the validated surface alone — `keyd`, Brave, Ghostty, and GNOME
      Shell all keep their current versions — so the exposure is narrower than
      feared: `xkeyboard-config` 2.47 -> 2.48 and `wayland` 1.25.0 -> 1.26.0.
      Check anyway, and concentrate on chords that depend on keysym and layout
      data. Verifying now attributes any breakage to the update rather than to
      later harness work. `[tier: med]`
- [x] On `gauss`: `just apply`, then re-verify the same acceptance map. Expect
      to be logged out of GNOME: the same apply on `hardy` restarted the user
      session units and ended the graphical session, and `nixos-rebuild` exits
      non-zero when that happens even though the switch succeeded. Close
      anything unsaved on `gauss`'s desktop first, and drive this from a Herdr
      session so the agent context survives the logout. Applied as generation
      18; the session dropped as predicted and the Herdr session reconnected on
      its own. `[tier: med]`
- [x] On both hosts, confirm the revision stamp took effect:
      `nixos-version --configuration-revision` should return the applied commit,
      and `nixos-rebuild list-generations` should no longer show `Unknown`. From
      here on that value is the drift check between the committed configuration
      and the running system. Both report `84c5ea7`. `[tier: low]`

Note that these applies carry two changes, not one: the moved lock, and
`system.configurationRevision` (commit `0eaf491`). The second is metadata only
and cannot affect runtime behavior, but the closure diff will show both.

Outcome: both hosts run nixpkgs `e2587ca` at revision `84c5ea7` with no failed
units. The `xkeyboard-config` 2.47 -> 2.48 exposure did not materialize; the
layout-sensitive bracket chords pass on both hosts. `just apply` now verifies
even when `nixos-rebuild` exits non-zero, which `gauss`'s apply exercised.

## Build the Workbench

- [ ] Boot `gauss`'s configuration unmodified in a VM and record what actually
      happens. Run `nixos-rebuild build-vm --flake .#gauss` and
      `./result/bin/run-gauss-vm`; capture whether it reaches a graphical GNOME
      session or a console, what the login state is, how long the build takes,
      and what warnings appear. Do not fix anything yet — this step exists to
      replace assumptions with observations. `[tier: med]`
- [ ] Make the VM reach a usable desktop session. Expect to need a VM-only
      configuration layer: autologin, a display resolution, and `virtio-gpu-gl`
      with a local GTK/SDL display so the guest receives raw scancodes including
      Super. Keep this layer clearly separated from host configuration; it must
      not alter what `just plan` would apply to a real machine. Confirm Super
      and Alt arrive intact using `wev` inside the guest. `[tier: high]`
- [ ] Add a `just vm HOST` recipe wrapping build and run, defaulting sensibly
      and working for both `gauss` and `hardy`. Note in its help text that VM
      mode ignores `hardware-configuration.nix` filesystems. Run `just check`.
      `[tier: low]`
- [ ] Determine whether `keyd` and the application mapper function inside the
      guest, since the mapper depends on a patched GNOME Shell extension. If
      they do not, record precisely what fails and which layer of the keybinding
      path the harness can therefore still verify. This result decides how much
      of the keybinding model is testable in a VM at all, so capture it in the
      ticket before proceeding. `[tier: high]`
- [ ] Prove one chord by hand in the headed VM: press the copy chord in Ghostty,
      confirm with `wl-paste` that the clipboard changed. This is the manual
      version of the assertion that the next step automates. `[tier: med]`
- [ ] Reproduce the same chord through the NixOS test driver. Write a minimal
      `runNixOSTest` for the trial host, build its `.driverInteractive`
      attribute, and drive `send_key` plus a `wl-paste` assertion from the REPL
      until the sequence is reliable. Record the working sequence verbatim.
      `[tier: high]`
- [ ] Commit that sequence as a headless check under `checks.<system>`, exposed
      through a `just` recipe. Keep it out of `just check` if it is slow; state
      the decision and its basis. Verify it fails when the binding is wrong — an
      assertion that has never failed has not been tested. `[tier: med]`
- [ ] Harvest durable facts: document the workbench and its three drive modes in
      `docs/`, index it per [docs/README.md](../../docs/README.md) and
      `docs/file-layout.md`, and state explicitly what the harness verifies
      versus what still requires real hardware. Delete the ticket, and move
      `desktop-test-harness` to the backlog's `## Closed` section. `[tier: low]`
