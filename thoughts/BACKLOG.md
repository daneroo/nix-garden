# Backlog

Unscheduled work, grouped by theme. Keep entries brief; move growing detail to
`tickets/` as described in [docs/workflow.md](../docs/workflow.md). Working
direction: [homelab-platform](design/homelab-platform.md).

## Now

Scheduled items go here (leave this comment)

## Fleet and Recovery

- [ ] host-inventory — inventory homelab machines, hardware, architecture,
      roles, criticality, and current state; ticket:
      [host-inventory](tickets/host-inventory.md)
- [ ] rationalize-current-state — reformat the redundant per-host row, gather
      from every reachable host, and report drift rather than leaving the
      comparison to the reader; ticket:
      [rationalize-current-state](tickets/rationalize-current-state.md)
- [ ] recovery-contract — define and exercise the minimum-fuss wipe, rebuild,
      restore, and verify path while `hardy` is non-load-bearing.

## Stateful Operations

- [ ] state-boundary — inventory state not owned by Nix: disks, secrets,
      backups, workload data, migrations, and remote resources.
- [ ] backup-reconciliation — define backup desired state, observation,
      convergence, restore testing, and failure reporting.
- [ ] safe-host-updates — design preview, drain, update, health verification,
      rollback, and recovery for machines with running workloads.
- [ ] storage-lifecycle — revisit Disko and filesystem choices with destructive
      testing, recovery, and data-lifecycle requirements defined first.

## Desktop

- [ ] desktop-baseline — build a daily-usable Linux desktop, tuned on `gauss`'s
      standard keyboard and backported to `hardy`, before optimizing or
      generalizing it.
- [ ] home-config-ownership — replace both hosts' system-tmpfiles writes beneath
      `/home/daniel` with a fresh-home-safe, user-owned mechanism and validate
      it from an empty home; deferred while bringing both machines online. The
      predicted failure was confirmed on 2026-07-25: on an empty home
      systemd-tmpfiles creates a root-owned `.config`, then its own unsafe
      path-transition guard skips every `L+` below it, silently and without
      failing the unit — losing the Ghostty keybindings, the keyd application
      map, and the GNOME extension on any reinstall. Patched in place for now by
      declaring each parent directory explicitly, which grew the very block this
      item exists to delete. `just e2e-vm --no-test --host HOST` is now the
      empty-home validation instrument this item calls for.
- [ ] visible-vm-session-actions — diagnose why the guided Alt+Shift+L and
      Alt+Shift+Q cases do not visibly lock or open the logout dialog in the
      `--show` VM even though real Gauss handles both; ticket:
      [visible-vm-session-actions](tickets/visible-vm-session-actions.md)
- [ ] hardy-external-keyboard-validation — complete the deferred real-hardware
      pass for native Alt/Ctrl/Super identity, the covered application and
      workspace chords, right Alt/AltGr, and isolation of the internal-only
      Alt+F6/F7 illumination adapter.
- [ ] vicinae-files-launch — fix the pre-existing Hardy Vicinae service PATH so
      the Files desktop entry's bare `nautilus` command resolves; keep this
      separate from keybinding behavior.
- [ ] niri-desktop — separately evaluate and, only if justified, assemble a
      complete standalone Niri desktop after PaperWM establishes which
      scrollable-workspace behavior matters; ticket:
      [niri-desktop](tickets/niri-desktop.md)

Shared direction and comparison criteria:
[scrolling-desktop](design/scrolling-desktop.md).

## Virtualization

- [ ] incus-host — evaluate Incus as the homelab VM and system-container layer,
      including storage, networking, backup, and upgrades.
- [ ] nixos-guests — decide how NixOS VM/container guests share the flake,
      inventory, roles, and reconciliation model with physical hosts.
- [ ] virtualization-test-lab — use Incus and the two available Proxmox hosts to
      accelerate rebuild, upgrade, recovery, and destructive workflow testing.

## Networking

- [ ] network-inventory — inventory subnets, VLANs, DNS, DHCP, routing, UniFi,
      Tailscale, and ownership boundaries.
- [ ] tailscale-reconciliation — define desired membership, identity, routes,
      ACLs, keys, health, and recovery.
- [ ] unifi-reconciliation — determine which router, DHCP, and network state can
      be safely observed, planned, applied, and verified.

## Security

- [ ] keyd-socket-permissions — replace Gauss's broad `Group = "users"` access
      to keyd's dynamic remapping socket with a dedicated group, without
      disrupting the validated desktop mapping.

## Nix Platform

- [ ] Decide whether to add Home Manager later.
- [ ] cli-baseline — give `hardy` and `gauss` a shared daily shell baseline:
      install Starship; match or improve the macOS prompt; settle nix-garden
      versus dotfiles ownership; add a nix-garden-scoped Starship custom module
      surfacing `scripts/current-state.sh`.
- [ ] If adding `thermald`, first revisit `docs/throttling.md`.
- [ ] gauss-power-profile — investigate why `gauss`'s internal NVMe buffered
      reads dropped from `3820 MB/sec` pre-install to `~1750 MB/sec` under
      NixOS; CPU governor is ruled out, root cause open. Check PCIe link
      speed/width and `amd_pstate`/EPP tuning; see
      [performance.md](../docs/performance.md#gauss-unresolved).
- [ ] flake-pinning — define a practical policy for input pinning, update scope,
      transitive inputs, and reviewable lock diffs; high priority.
- [ ] reboot-awareness — make `just plan` and `just apply` explicitly report
      whether the proposed closure changes require a reboot or a desktop
      re-login, including the basis for that assessment and post-change
      verification. Observed 2026-07-25 on `hardy`: a routine nixpkgs bump
      restarted the GNOME user units and ended the graphical session with no
      warning. Re-login is a distinct category from reboot and currently has no
      signal at all; the Herdr session survived, which is how the apply stayed
      recoverable.
- [ ] nix-formatting — choose and integrate the repository's Nix formatter and
      formatting check; ticket: [nix-formatting](tickets/nix-formatting.md)
- [ ] module-architecture — learn and choose a clearer flake/module structure
      with explicit reuse between `hardy` and `gauss`; keep the migration
      behavior-preserving and separate from keybinding and PaperWM experiments;
      research: [module-architecture](research/module-architecture.md)
- [ ] development-environments — harvest useful nixvana lessons into development
      shells exercised by real projects, CI, and agent workflows.
- [ ] reconciliation-pattern — turn [reconciliation](../docs/reconciliation.md)
      into concrete conventions and reusable checks as dynamic systems appear.
- [ ] clan-reference — study Clan's solutions for fleet management, secrets,
      backups, networking, and installation before designing equivalents.
- [ ] generation-retention — configure automatic cleanup of old NixOS and
      profile generations while preserving a deliberate rollback window; ticket:
      [generation-retention](tickets/generation-retention.md)
- [ ] nh-iteration — evaluate `nh` for planned diffs, activation, rollback, and
      generation management in the normal host workflow.
- [ ] related-reconcilers — inventory reusable lessons and boundaries from the
      `dotfiles` Go reconcilers and `qcic` operations experiments.

## Self-Hosting Development

- [ ] hardy-current-state — verify whether the committed configuration is
      currently applied and record the running generation and drift.
- [ ] hardy-dev-loop — make `hardy` the primary editor and executor of this
      repo: clone, authenticate, edit, check, preview, apply, verify, commit,
      and push.
- [ ] herdr-reboot-history — validate opt-in Herdr pane screen replay plus
      append/synchronized Bash history so restored panes retain useful context
      across server and host restarts; ticket:
      [herdr-reboot-history](tickets/herdr-reboot-history.md)
- [ ] remote-access — configure and verify SSH access suitable for development
      and recovery without weakening host security.

## Repository Workflow

- [ ] agent-skills-workflow — evaluate a small, curated Agent Skills toolkit;
      the first repo-local pilot, `grilling`, is already installed; ticket:
      [agent-skills-workflow](tickets/agent-skills-workflow.md)
- [ ] legacy-harvest — harvest useful legacy findings, then delete `legacy/`;
      Git retains the history.
- [ ] shared-repo-workflow — settle the shared docs/thoughts convention with
      Prosodio; ticket: [shared-repo-workflow](tickets/shared-repo-workflow.md)
- [ ] concise-agent-docs — make agent-facing instructions in nix-garden and
      Prosodio substantially shorter and easier to scan; ticket:
      [concise-agent-docs](tickets/concise-agent-docs.md)

## Documentation

- [ ] hardy-hardware-notes — decide whether to keep or consolidate the inherited
      performance and throttling notes for `hardy`; ticket:
      [hardy-hardware-notes](tickets/hardy-hardware-notes.md)

## Closed (newest first)

One line per closed item — this section doubles as the ticket archive index.
Prune old lines freely; Git keeps everything.

- 2026-07-30 e2e-replace-refactor — simplified the live Bun suite (`pressChord`,
  extracted `brave.ts`), made its output readable (quiet-on-success /
  loud-on-failure), added the first gated GNOME global (`Alt+Shift+Q`
  logout-cancel), and unified the entry points (`just e2e` / `just e2e-vm`).
  Running the Bun suite in the VM was attempted and reverted — the VM's window
  focus blocks its assertions; Python stays the VM behavioural path. Plan:
  [e2e-replace-refactor](plans/archive/e2e-replace-refactor.md)
- 2026-07-29 e2e-fix-or-replace — replaced the slow VM-only development loop
  with a guarded Bun suite that exercises deployed Ghostty and Brave bindings
  through physical pre-keyd input on the live Gauss desktop; reference:
  [e2e-testing](../docs/e2e-testing.md); plan:
  [e2e-fix-or-replace](plans/e2e-fix-or-replace.md)
- 2026-07-28 paperwm-trial — adopted switchable PaperWM scrollable tiling on
  Hardy and Gauss, floated Vicinae by default, and exposed one system-owned
  toggle through the shell and Vicinae; reference:
  [tiling-windows](../docs/tiling-windows.md); plan:
  [paperwm-trial](plans/paperwm-trial.md)
- 2026-07-28 simplified-keybinding-model — replaced the global Alt-to-Super
  carrier with direct native Alt bindings on Hardy and Gauss, retained only
  Brave's focused chord translation and Hardy's internal-keyboard illumination
  adapter, and proved one 27-case host-selectable E2E contract plus complete
  real-hardware acceptance; reference: [keybindings](../docs/keybindings.md);
  plan: [simplified-keybinding-model](plans/simplified-keybinding-model.md)
- 2026-07-26 current-state — added one command showing the running NixOS
  configuration and nixpkgs revisions beside the repository branch and
  dirty-aware description; plan: [quick-utilities](plans/quick-utilities.md)
- 2026-07-26 quick-cli-packages — added `lazygit`, `doggo`, and `dig` to the
  shared host packages; plan: [quick-utilities](plans/quick-utilities.md)
- 2026-07-26 desktop-test-harness — added persistent exploration, visible
  demonstration, and fresh headless regression workflows over the real host
  configuration; proved Ghostty's primary chords and GNOME lock/unlock in a
  disposable VM; reference: [e2e-testing](../docs/e2e-testing.md); plan:
  [desktop-test-harness](plans/archive/desktop-test-harness.md)
- 2026-07-23 hardy-keybinding-backport — restored keyboard illumination and
  1Password/Brave integration, validated a Chromebook-specific Ctrl/Cmd/Option
  model plus Ghostty, Brave, Vicinae, lock, screenshot, and logout bindings, and
  secured keyd's mapper socket with a dedicated group; settled map:
  [docs/keybindings.md](../docs/keybindings.md)
- 2026-07-23 keybinding-model — validated a macOS-equivalence keybinding map for
  Ghostty, Brave, Vicinae, and 1Password on `gauss` (Alt↔Super swap via `keyd` +
  a patched GNOME Shell extension); settled facts harvested to
  [docs/keybindings.md](../docs/keybindings.md); Hardy's completed backport is
  recorded immediately above
- 2026-07-23 gauss-onboarding — installed NixOS on `gauss` as a clone of
  `hardy`, generalized the flake/`Justfile`/bootstrap script to multi-host,
  verified `just check`/`just plan` on the host itself, and handed off execution
  to Claude Code on `gauss` via Herdr; folded in `multi-host-layout`, which has
  no remaining independent scope; plan:
  [gauss-onboarding](plans/archive/gauss-onboarding.md)
- 2026-07-23 gaussmic-github-key-retirement — deleted the temporary
  `gaussmic-2026-07-22-temp` GitHub SSH key after confirming Gaussmic's disk is
  gone for good.
- 2026-07-22 herdr-workflow — installed and verified Herdr v0.7.5 on `hardy`,
  including remote detach/reattach and native agent detection; plan:
  [herdr-workflow](plans/archive/herdr-workflow.md)
- 2026-07-22 legacy-fact-collector — removed the distro-hopping hardware probe;
  durable Hardy throttling evidence remains in `docs/`.
- 2026-07-12 bootstrap-flake — established the pushable, rebuildable flake and
  documented the remote-clone bootstrap path later proved while onboarding
  `gauss`; plan: [bootstrap-flake](plans/archive/bootstrap-flake.md)
- 2026-07-12 repository-command-surface — implemented and exercised the
  `plan`/`apply` workflow, passwordless sudo, and the locked unstable migration;
  plan:
  [repository-command-surface](plans/archive/repository-command-surface.md)
- 2026-07-12 migrate-to-nix-garden — consolidated both repository histories and
  made nix-garden the verified live fleet repository; plan:
  [migrate-to-nix-garden](plans/archive/migrate-to-nix-garden.md)
