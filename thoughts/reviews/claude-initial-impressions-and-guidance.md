# Claude — Initial Impressions and Guidance

Review date: 2026-07-12. Scope: the whole repository except `legacy/` — the
flake, `hosts/hardy`, the Justfile, scripts, `docs/`, and `thoughts/` including
[homelab-platform](../design/homelab-platform.md) and the backlog.

## Summary Assessment

This is a strong restart. The instincts are right: start with one real host, a
proven edit-check-build-diff-apply loop, explicit guardrails, and a backlog that
defers abstraction until a second consumer exists. The plan/apply workflow
deliberately mirrors Terraform, and the reconciliation doc correctly names the
boundary Nix does not cross. Most homelab Nix repos fail by over-abstracting on
day one; this one has explicitly armored itself against that.

The three headline recommendations, expanded below:

1. **The biggest missing lever is virtual iteration.** Everything currently
   validates against the live `hardy`. `nixos-rebuild build-vm` and the NixOS
   integration test framework give you a disposable copy of any host in seconds,
   and the test driver can literally press keys and OCR the screen — which is
   exactly your desktop keybinding validation goal.
2. **Do the recovery proof on a VM before doing it on metal.** `nixos-anywhere`
   plus `disko`, exercised against a throwaway Proxmox VM, gets you the "wipe,
   one command, back to baseline" contract with zero hardware risk. It is closer
   than the backlog assumes.
3. **Watch the process-to-substance ratio.** There are ~1,300 lines of process
   and thought documentation supporting ~120 lines of Nix. The process quality
   is genuinely high, but several backlog items are process about process
   (shared-convention sync, workflow skills, doc conciseness). Timebox those;
   let the Nix surface catch up.

## What Is Working Well

- **One real host first.** The lessons-learned section is honest about the
  earlier rabbit holes (custom ISOs, Clan, Proxmox provisioning), and the
  guardrails encode that honesty. Keep them.
- **The `just plan` / `just apply` loop.** Build-then-diff-then-confirm with
  `nix store diff-closures` is the right shape, and `_verify` closing the loop
  (running system matches `./result`) is a detail most people skip.
- **Evidence-based plans.** The herdr plan records activation evidence (store
  paths, service states) rather than just checkboxes. That habit is worth more
  than any tooling choice.
- **Deliberate lock discipline.** Pinning Herdr to a tag without letting it
  advance `nixpkgs`, and reviewing `flake.lock` diffs, shows the right reflexes.
- **Scoped sudo compromise.** Passwordless `wheel` sudo is documented as
  temporary with an explicit revert condition. Good pattern: every security
  relaxation carries its own expiry criterion.

## Risks and Course Corrections

### Process weight

The workflow docs are well-written, but items like `shared-repo-workflow`,
`shared-workflow-skill`, and `concise-agent-docs` are meta-work with no homelab
outcome. Suggested rule: at most one process item in flight at a time, and never
in `## Now` while a platform item is available. The workflow will settle faster
through use than through refinement.

### Interactive recipes block agents and CI

`just plan` and `just apply` prompt via `read`. That is correct for a human at a
terminal, but it means no agent, cron job, or CI runner can execute the
non-destructive parts unattended. Suggest splitting the pure gates from the
conversations:

- Keep `just check` fully non-interactive (it already is).
- Add a non-interactive `just pre-flight` (check + build + diff, no prompts) —
  AGENTS.md already references `just pre-flight`, but the Justfile does not
  define it; today that reference dangles.
- Keep prompts only where state changes: input updates and `apply`.

This also becomes the CI job for free: build the `hardy` toplevel on every push,
so a broken commit is caught even when no machine has pulled it.

### Small flake and Justfile notes

- `flake.nix` does `import nixpkgs { config.allowUnfree = true; }` at the top
  level solely for `bootstrapPackages`, while `hosts/hardy` also sets
  `nixpkgs.config.allowUnfree`. That is two nixpkgs evaluations and two places
  owning the same policy. Simpler: make the bootstrap-packages module a function
  of the module system's own `pkgs`
  (`({ pkgs, ... }: { environment.systemPackages = with pkgs; [ ... ]; })`) and
  drop the top-level import.
- The bootstrap package list is really a "development workstation" role hiding
  in the flake entry point. No need to move it today, but when a second host
  appears, this becomes `modules/roles/dev-workstation.nix`, and the flake goes
  back to being thin, as the design doc intends.
- Not pinning Herdr's inputs with `follows` is a defensible choice (you get
  upstream's tested closure) — just be aware it can carry a second nixpkgs
  closure. Check `nix flake metadata` occasionally.
- `_verify`'s `sudo -n true` verifies passwordless sudo survives, not that the
  switch succeeded; worth a comment so future-you knows it is intentional.
- Consider `nvd diff /run/current-system ./result` alongside or instead of
  `nix store diff-closures` — same information, considerably more readable. `nh`
  (already on the backlog) wraps this well; adopting just `nvd` is the low-cost
  first step.
- `nixos-hardware` is worth adding as an input for `hardy`: at minimum
  `common-cpu-intel` and `common-pc-ssd` profiles, and check whether a
  Chromebook/MrChromebox profile exists before hand-rolling quirks that
  `docs/throttling.md` currently tracks.

## The Missing Lever: Virtual Iteration

Everything below shortens the loop from "minutes and a real machine" to "seconds
and a throwaway".

### `build-vm` — a disposable hardy

```sh
nixos-rebuild build-vm --flake .#hardy
./result/bin/run-hardy-vm
```

This boots the actual host configuration in QEMU, with a copy-on-write disk,
without touching hardware. Caveat: `hardware-configuration.nix` filesystems are
ignored in VM mode, so it validates services, packages, users, and desktop
config — not boot/disk layout. Add a `just vm` recipe; it will become the
default way to try anything risky.

### The NixOS test framework — your desktop testing answer

The item `desktop-test-harness` is already solved upstream. NixOS integration
tests (`pkgs.testers.runNixOSTest`) boot one or more VMs and drive them from a
Python script that can:

- `machine.send_key("ctrl-alt-t")` — synthetic keyboard input;
- `machine.screenshot("name")` — capture the framebuffer;
- `machine.wait_for_text("...")` — OCR the screen and assert on it;
- `machine.wait_for_unit(...)`, `machine.succeed(...)` — service assertions.

Upstream nixpkgs contains working graphical tests for GNOME, Sway, and other
compositors — copy their structure. This is precisely how to validate "does this
Niri keybinding do what a macOS-trained hand expects" reproducibly, and it
composes with agent-assisted review (an agent can read the screenshots and OCR
output). Wire tests into `flake.nix` `checks.<system>.*` so `nix flake check`
grows teeth; keep slow graphical tests out of the default gate and run them via
`nix build .#checks...` on demand.

### Agent computer use — the judgment layer over the test framework

Daniel is deliberately cultivating agent computer use across multiple harnesses
(Claude, Codex, Antigravity, Hermes, OpenCode). That capability and the test
framework are complementary layers, not alternatives:

- **Agents explore; tests pin.** A computer-use agent is the right tool for
  open-ended validation — "log in, try the workspace keybindings, tell me what
  feels wrong" — and for authoring the deterministic regression that pins each
  finding. The NixOS test is the artifact the exploration leaves behind; it
  keeps passing after the agent session ends.
- **Give agents the disposable screen, not the live one.** The `build-vm`
  variant can run headless with a VNC display
  (`QEMU_OPTS="-vnc :0" ./result/bin/run-hardy-vm`), so any computer-use harness
  drives a throwaway copy of `hardy` instead of the desktop Daniel is sitting
  at. Reset is deleting a qcow2 overlay.
- **`driverInteractive` is text-first computer use.** Building a NixOS test's
  `.driverInteractive` attribute drops into a Python REPL where `machine`
  objects expose `send_key`, `screenshot`, `wait_for_text` (OCR), and shell
  execution. Any terminal agent can drive a graphical VM through it — no vision
  or native computer-use support required, and every action is replayable as a
  script. This is likely the highest-leverage agent interface in the whole
  testing stack.
- **Multi-harness is an argument for the process investment.** With five
  harnesses in play, harness-neutral instructions (AGENTS.md as canonical,
  skills as portable procedures) stop being meta-work and become the interface
  those agents share. The earlier process-weight caution still applies in one
  form: each process artifact should be exercised by a real agent doing real
  work soon after it is written, or it is speculation.

### Cheap fast checks

For the inner loop, evaluation alone catches most config errors in seconds:

```sh
nix eval .#nixosConfigurations.hardy.config.system.build.toplevel.drvPath
```

Worth a `just eval` for editing sessions where a full build is overkill.

## Recovery: Do It on a VM First, and Sooner

The backlog treats `recovery-contract` and `storage-lifecycle` (Disko) as later
work gated on safety. Agreed for `hardy` metal — but the standard stack for your
exact stated Phase 2+ goal already exists, and the Proxmox hosts make it
risk-free to learn:

- **[disko](https://github.com/nix-community/disko)** — declarative
  partitioning, the piece that makes `hardware-configuration.nix` fully
  reproducible instead of snapshot-of-what-the-installer-did.
- **[nixos-anywhere](https://github.com/nix-community/nixos-anywhere)** — SSH to
  anything bootable (installer ISO, or even a running foreign Linux), partition
  per disko, install the flake, reboot into the finished system. One command
  from another machine.

Suggested exercise, entirely on a throwaway Proxmox VM: define a minimal
`hosts/testvm` with a disko layout, run `nixos-anywhere` at it, wipe it, run it
again. That is the recovery contract, proven, in an afternoon, with zero risk.
Then `gauss` is the first metal target, and `hardy` only after its data story is
defined. This inverts the current implicit ordering — recovery tooling need not
wait for the storage-lifecycle design if it is exercised on disposable targets.

## Secrets

Recommendation: **sops-nix**, adopted early, with age keys derived from each
host's SSH host key (`ssh-to-age`). Rationale:

- It is the community default with the most documentation and examples (agenix
  is the lighter alternative; both are fine, sops-nix scales better to many
  hosts and many secrets and supports partial-file encryption).
- The bootstrap ordering works: the host SSH key exists after install, you add
  its derived age key to `.sops.yaml`, re-encrypt, and the host can decrypt on
  next activation. This composes with nixos-anywhere, which can even inject the
  host key at install time.
- Secrets land in `/run/secrets` (not world-readable in the Nix store), owned
  per-service.

Keep 1Password as the human vault (it already bootstraps your credentials);
sops-nix is for what _services_ need at activation: Tailscale auth keys, restic
repo passwords, API tokens. A good first secret: the Tailscale auth key, because
it immediately buys the remote dev loop below. Clan's vars system solves the
same problem; per your own guardrail, study it, adopt sops-nix now.

## Networking

- **Tailscale first.** `services.tailscale.enable = true` plus an auth key from
  sops-nix makes every host reachable for the self-hosting loop, SSH, and Herdr
  regardless of UniFi state. Tailscale ACLs have an official GitOps workflow
  (HuJSON policy file in a repo, applied by CI) — that is your
  desired-versus-actual story for the overlay network, nearly free.
- **UniFi: constrain the ambition.** The controller is authoritative, imperative
  state. The pragmatic reconciliation is the Terraform/OpenTofu UniFi provider
  scoped to exactly the durable facts you care about — static DHCP reservations
  and DNS names for inventory hosts — and nothing else. This fits
  `docs/reconciliation.md` perfectly (Terraform _is_ the observe/plan/converge
  model), keeps blast radius small, and leaves the UniFi UI usable for
  everything you did not claim. Resist importing the whole controller config.
- **DNS.** Start with Tailscale MagicDNS for host names. A self-hosted resolver
  (unbound/blocky) is a fine later server workload, not a prerequisite.

## Monitoring

Make it the first real _server_ workload on `hardy` — it exercises the "desktop
and server roles on one host" claim and gives every later experiment
observability:

- `services.prometheus.exporters.node.enable = true` on every host (trivial).
- One Prometheus + Grafana instance, fully declarative via the NixOS modules
  (dashboards and datasources can be provisioned from the repo).
- Alerting can wait; when it arrives, harvest the `qcic` lessons as the design
  input rather than resurrecting its implementation.
- Cheap wins meanwhile: `services.smartd`, and systemd unit failure
  notifications.

## Desktop and Keybindings

- **Adopt Home Manager when the desktop work starts, not later.** Niri and
  Hyprland are configured in user space; without HM you will end up templating
  dotfiles by hand, which is the worst of both worlds. Use HM as a NixOS module
  (`home-manager.nixosModules.home-manager`) so one `just apply` covers both
  system and user — no separate activation loop, which matches your single-loop
  philosophy.
- **Look at `keyd` (or kanata) for the macOS-consistent binding layer.**
  `services.keyd` remaps at the kernel-input level, below the compositor, so one
  declarative config gives Cmd-like behavior across compositor, terminal,
  editor, and browser instead of per-application binding tables. This may
  collapse much of the `keybinding-model` item.
- **Compositor choice:** both Niri and Hyprland are packaged and current;
  Hyprland has more community examples, Niri's scrolling model is genuinely
  different — build both as VM tests (see above) and drive the real choice from
  a week of daily use each. Do not design the cross-platform binding abstraction
  before that week; evidence first, per your own guardrails.
- The NixOS test driver (`send_key` + OCR) is how bindings become regression
  tests once chosen.

## Virtualization

Layered recommendation, in adoption order:

1. **Keep Proxmox as the substrate, not the target.** The two Proxmox hosts are
   your disposable-VM factory for nixos-anywhere drills, multi-host experiments,
   and upgrade rehearsals. Managing Proxmox itself declaratively was one of the
   old rabbit holes; do not reopen it.
2. **`virtualisation.oci-containers` for the Docker-shaped itch.** It maps
   container workloads onto declarative NixOS options backed by systemd-managed
   Podman/Docker. You keep the container ecosystem you love, inside the same
   flake, diff, and rollback loop as everything else. This is the
   lowest-friction bridge between "Docker is simple" and "Nix is declarative",
   and it is production-adequate for typical homelab services.
3. **Incus when a real multi-guest need appears.** NixOS support is good
   (`virtualisation.incus.enable`, including declarative preseed of storage
   pools and networks). For NixOS guests, `nixos-generators` can emit Incus/LXC
   images from the same flake, and the upstream image server also carries NixOS
   images. System containers running NixOS have some friction (nested systemd,
   id-mapping); VMs via Incus are smoother for full-NixOS guests.
4. **Know that `microvm.nix` exists** for very light, flake-native NixOS VMs
   declared as host config — arguably a better fit than Incus if guests are
   always NixOS and always declared in this repo. Evaluate the two against a
   concrete first guest, not in the abstract.
5. **Kubernetes: not yet.** `services.k3s` exists when a workload actually
   demands it; nothing in the current goals does.

## Pinning and Updates

For the `flake-pinning` backlog item, a policy that has aged well elsewhere:

- Track `nixos-unstable` while the fleet is one non-critical host (current
  choice — fine, and it matches stateVersion expectations already in place).
- Update small and often (weekly beats monthly; smaller diffs, easier
  bisecting). `nix flake update --commit-lock-file` gives you one clean commit
  per update, and `just plan`'s diff review does the rest.
- When a host becomes load-bearing, decide _then_ whether it moves to the stable
  channel (`nixos-26.05`) with unstable available via overlay for selected
  packages. Per-host channels are easy once hosts are modules.
- Transitive inputs: default to accepting upstream locks (as done with Herdr);
  reach for `follows` only when closure size or version skew demonstrably hurts.

## Suggested Order of Execution

The backlog contents are right; this is mostly a re-sequencing for loop speed:

1. **`just pre-flight` + non-interactive gates** — unblock agents and CI; fixes
   the dangling AGENTS.md reference. (hours)
2. **`nix fmt` via `nixfmt-rfc-style`** — `formatter` flake output, check in
   `just check`, one mechanical normalization commit. The official-style
   formatter question is settled upstream; do not spend long here. (hours)
3. **`just vm` + one smoke NixOS test** wired into `checks` — the fast loop
   exists from here on. (a day)
4. **sops-nix with the Tailscale key as first secret; Tailscale on `hardy`** —
   remote dev loop from anywhere, and the secrets pattern established while the
   config is still small. (a day)
5. **nixos-anywhere + disko drill on a Proxmox VM, then `gauss`** — the recovery
   contract, proven on disposable targets. (an afternoon, then repeat)
6. **Monitoring as first server workload** — node exporters everywhere,
   Prometheus+Grafana on `hardy`. (a day)
7. **Desktop baseline with Home Manager; compositor bake-off in VMs; keyd** —
   now backed by the test harness from step 3. (ongoing)
8. **Virtualization (oci-containers, then Incus/microvm.nix)** — once steps 1–5
   make guest experiments cheap and reversible. (as needed)

CI (GitHub Actions building the `hardy` toplevel, with a Nix cache action) slots
in naturally after step 3 and keeps every push honest even before any machine
pulls it.

## References

- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere) — remote
  install over SSH.
- [disko](https://github.com/nix-community/disko) — declarative disk layout.
- [sops-nix](https://github.com/Mic92/sops-nix) — secrets provisioning.
- [nixos-hardware](https://github.com/NixOS/nixos-hardware) — hardware quirk
  modules.
- [Home Manager](https://github.com/nix-community/home-manager) — user-space
  configuration.
- [NixOS test framework](https://nixos.org/manual/nixos/stable/#sec-nixos-tests)
  — VM integration tests with keyboard/OCR drivers.
- [microvm.nix](https://github.com/astro/microvm.nix) — flake-native NixOS
  microVMs.
- [nixos-generators](https://github.com/nix-community/nixos-generators) — image
  outputs (Incus/LXC/ISO/…) from one config.
- [nvd](https://gitlab.com/khumba/nvd) — readable closure diffs.
- [keyd](https://github.com/rvaiya/keyd) — system-level key remapping.
- [Tailscale GitOps for ACLs](https://tailscale.com/kb/1204/gitops-acls) —
  policy-as-code for the tailnet.
- [nix.dev](https://nix.dev/) — the maintained official learning reference.
