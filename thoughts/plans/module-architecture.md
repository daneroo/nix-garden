# module-architecture

Status: active

Goal: recompose the flake with flake-parts, import-tree, and Dendritic feature
modules grouped into `base`, `desktop`, and `gnome` aspects, so that ownership,
host selection, and output definition are each answered by one file, with the
public outputs kept and both hosts working as before.

Evidence, inventory, and decisions: [ticket](../tickets/module-architecture.md).
Read it first; this plan does not repeat the reasoning. Daniel settled the
design questions in a grilling session on 2026-09-18; the ticket records the
answers.

## Ground rules

- Execute on a NixOS host, `gauss` preferred, on branch `module-architecture`
  created from `main`. `galois` cannot run `just plan` or `just e2e-vm`. Run the
  executor with a current Claude Code:
  `NIXPKGS_ALLOW_UNFREE=1 nix run --impure github:NixOS/nixpkgs/nixos-unstable#claude-code`.
- Never run `just apply`, `nixos-rebuild switch`, or `just update`. Builds,
  checks, plans, evaluations, and VM tests only.
- `just check` after every edit and before every commit. Logical commits; no
  squashing, rebasing, merging, or pushing `main` without Daniel's direction.
  Pushing the branch itself is fine.
- Keep this file's checkboxes current. Set `Status: active` in the first branch
  commit and `Status: done` only after stage 5.
- The bar is a working system and a clearer design, not byte-identical
  derivations. `scripts/output-fingerprint.sh` is a cheap diagnostic: its
  `semantic` lines are an order-independent list of what a configuration
  contains, so a `diff` against the baseline shows anything dropped or renamed
  by accident. Name every removal in the commit message; do not chase
  derivation-path equality.
- Small normalizations that fall out of unifying the two hosts (one Ghostty
  config text, one comment per fact, dead duplication) are in scope and are
  named in the commit that makes them. Anything a user would notice (a binding,
  a service, a package, a group, a security model) stays as it is; the backlog
  tracks the known ones.
- Tiers route effort: `low` is mechanical and fully specified here, `med` has a
  written contract below, `high` stays with the coordinating agent.
- Rollback for every stage is `git reset --hard` to the previous stage's commit
  on the branch. Nothing touches `main` or a running system until Daniel merges
  and applies.

## Target topology

```text
flake.nix                        inputs; mkFlake; imports: flakeModules.modules,
                                 import-tree ./modules, ./hosts
hosts/
  default.nix                    inventory: host list, imports, nixosConfigurations
  hardy/default.nix              modules.nixos.host-hardy: hardware + aspects + exceptions
  hardy/hardware-configuration.nix
  gauss/default.nix
  gauss/hardware-configuration.nix
modules/                         every file auto-imported; each is a flake-parts module
  base/                          registers into modules.nixos.base
    nix-workflow.nix  systemd-boot.nix  locale.nix  networkmanager.nix
    tailscale.nix  openssh.nix  user-daniel.nix  cli-baseline.nix
  desktop/                       registers into modules.nixos.desktop
    keyd.nix  ghostty.nix  brave.nix  vicinae.nix  onepassword.nix
    e2e-injection.nix  vm-variant.nix
  gnome/                         registers into modules.nixos.gnome
    session.nix  keybindings.nix  paperwm.nix  keyd-extension.nix
  e2e/                           harness, registers nowhere
    vm-layer.nix                 modules.nixos.vm-layer
    desktop-tests.nix            perSystem.packages.test-desktop*, test-report
tests/                           unchanged
```

Conventions:

- `flake.nix` imports `inputs.flake-parts.flakeModules.modules`,
  `(inputs.import-tree ./modules)`, and `./hosts`.
  `systems = [ "x86_64-linux" ]`. Nothing else lives there.
- Every file under `modules/` is live: import-tree imports it. A file that is
  not ready is named with a leading underscore or not created. Directory name is
  the aspect the file registers into; `e2e/` is the exception and says so.
- A feature file defines exactly one named module and registers it:

  ```nix
  { config, ... }:
  {
    flake.modules.nixos.locale = {
      time.timeZone = "America/Toronto";
      i18n.defaultLocale = "en_CA.UTF-8";
    };
    flake.modules.nixos.base.imports = [ config.flake.modules.nixos.locale ];
  }
  ```

  Features reference each other only through `config.flake.modules.nixos`, never
  by path. A file may define the module as a function
  `{ pkgs, lib, ... }: { ... }` when it needs them.

- `hosts/<name>/default.nix` is a flake-parts module defining
  `flake.modules.nixos.host-<name>`, whose `imports` are the hardware file and
  the aspects (`base`, `desktop`, `gnome`), followed by `networking.hostName`,
  `system.stateVersion`, and that host's exceptions, each with a comment naming
  why it is host-specific. A host needing a subset imports individual features
  instead of an aspect.
- `hosts/default.nix` holds `hosts = [ "hardy" "gauss" ]`, imports each host
  directory from it, and defines `flake.nixosConfigurations` with
  `inputs.nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = [ config.flake.modules.nixos."host-${name}" ]; }`.
  The `Justfile` and `scripts/e2e-vm.sh` keep their `blessed_hosts` copies;
  `rationalize-current-state` may collapse them later.
- `tests/lib.nix` keeps its `{ hostName; hostModules; vmLayer; }` contract.
  `desktop-tests.nix` passes `[ config.flake.modules.nixos."host-${name}" ]` and
  `config.flake.modules.nixos.vm-layer`, iterating
  `builtins.attrNames config.flake.nixosConfigurations`.
- `perSystem` sets
  `_module.args.pkgs = import inputs.nixpkgs { inherit system; config.allowUnfree = true; }`
  so test tooling may be unfree, as today.
- Comments move with the configuration they explain. Host-only knowledge stays
  in the host file; shared knowledge lands in the feature file once.
- `nix flake check` prints "The following flake outputs are unchecked: modules."
  once per run. That is expected and cosmetic.

## Feature contracts

Each entry lists what the feature owns, and where the lines come from today (`H`
hardy, `G` gauss, `F` flake inline block, `M` modules/).

`base`:

- `nix-workflow`: `nix.settings.experimental-features` (H, G),
  `nixpkgs.config.allowUnfree` (H, G), `system.configurationRevision` from
  `inputs.self` (F), `programs.nh` with the canonical `/home/daniel/nix-garden`
  path (F).
- `systemd-boot`: `boot.loader.systemd-boot.enable` and
  `boot.loader.efi.canTouchEfiVariables` (H, G), `configurationLimit = 20` and
  `bootCounting` with their retention comment (F).
- `locale`: `time.timeZone`, `i18n.defaultLocale` (H, G).
- `networkmanager`: `networking.networkmanager.enable`, `networking.domain` (H,
  G). Hostname stays in the host.
- `tailscale`: `services.tailscale.enable` (F).
- `openssh`: `services.openssh` block (H, G).
- `user-daniel`: `users.users.daniel` account, description, `networkmanager` and
  `wheel` groups, the `galois` authorized key (H, G);
  `security.sudo.wheelNeedsPassword = false` with its temporary-policy comment
  (H, G); tmpfiles `d` lines for `.config`, `.local`, `.local/share` (H, G) with
  the ownership-transition explanation. `keyd` group membership, `linger`, and
  `packages = [ keyd ]` belong elsewhere.
- `cli-baseline`: the bootstrap package list (F) including Herdr from
  `inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default`,
  `programs.git.enable` (H, G), and the comment explaining why 1Password is not
  in the list.

`desktop` (compositor-agnostic):

- `keyd`: `services.keyd.enable`, `UMask = "0007"` on the unit,
  `users.users.daniel.packages = [ keyd ]` with the PATH comment (H, G); a
  comment stating that keyboards, the `alt+shift` layer, and the socket group
  model are host declarations. Hardy keeps `keyboards.internal`, the `keyd`
  group, `CapabilityBoundingSet`, and the E2E device id; gauss keeps
  `keyboards.default` and `Group = "users"`.
- `ghostty`: one Ghostty config file (the two differ only in comments) with
  tmpfiles `d .config/ghostty` and its `L+` (H, G). The package stays in
  `cli-baseline`.
- `brave`: `xdg.mime.defaultApplications` (F); the keyd application map
  `app.conf` translating Alt chords for the focused Brave window, with tmpfiles
  `d .config/keyd` and its `L+` (H, G). The package stays in `cli-baseline`.
- `vicinae`: `environment.systemPackages = [ vicinae ]` and the user service (H,
  G) with the no-NixOS-module comment.
- `onepassword`: `programs._1password-gui` with `polkitPolicyOwners` and
  `programs._1password.enable` (H, G) with the browser-support comment.
- `e2e-injection`: current `modules/e2e.nix` (M) plus a comment naming hardy's
  `2333:6666` keyd id and the `keyboards.vm` addition in `tests/lib.nix`.
- `vm-variant`: current file (M), importing
  `config.flake.modules.nixos.vm-layer`.

`gnome`:

- `gnome-session` (file `session.nix`): `services.xserver`, GDM, GNOME, xkb,
  printing (H, G); PipeWire, rtkit, PulseAudio off (H, G);
  `programs.dconf.enable` (H, G); one dconf database with `org/gnome/shell`
  (`always-show-log-out`, `enabled-extensions` naming the keyd and PaperWM
  UUIDs, `favorite-apps`) and `org/gnome/desktop/peripherals/mouse` (H, G); the
  dconf disjoint-keys assertion. `environment.gnome.excludePackages` stays a
  gauss exception.
- `gnome-keybindings` (file `keybindings.nix`): the GNOME side of
  `docs/keybindings.md`: one dconf database with `org/gnome/shell/keybindings`,
  `org/gnome/desktop/wm/keybindings`, the media-keys `screensaver` and
  `custom-keybindings` list and `custom0..2` (H, G), referencing `pkgs.vicinae`
  and `pkgs.gnome-session`.
- `paperwm`: current `modules/paperwm.nix` body (M) plus a dconf database with
  `org/gnome/shell/extensions/paperwm` winprops (H, G).
- `keyd-gnome-extension` (file `keyd-extension.nix`): the patched extension
  derivation and metadata patcher with tmpfiles `d .local/share/gnome-shell`,
  `d .../extensions`, and the extension `L+` (H, G).

Harness (`e2e/`, no aspect):

- `vm-layer`: current file (M), named only; never imported by a host.
- `desktop-tests.nix`: the four packages, in `perSystem`.

Host files after stage 3 contain only: the hardware import, the three aspect
imports, `networking.hostName`, `system.stateVersion`, and the exceptions listed
in the ticket, each with its existing comment.

## Steps

### Stage 0 — branch and baseline `[tier: low]`

Scope: no configuration edits. Depends on: nothing.

- [x] On `gauss` confirm `~/nix-garden` is clean on `main` at `331be9f` or
      later, then `git switch -c module-architecture`.
- [x] Set this plan to `Status: active`; commit.
- [x] `mkdir -p /tmp/module-architecture` and save
      `scripts/output-fingerprint.sh main > /tmp/module-architecture/00-baseline.txt`.
- [x] `just check` passes.
- [ ] `just plan` on `gauss` (done), and over SSH on `hardy` (pending SSH
      access), builds and reports no package changes against the running system.
      Do not apply.
- [x] `just e2e-vm --host hardy` and `just e2e-vm --host gauss`; record pass
      counts and wall time in the ticket. A pre-existing failure is recorded
      before any refactor edit and does not block; later runs are compared
      against it.
- [x] `just e2e-vm --no-test --host gauss` reaches the GNOME session; close the
      VM. `just omarchy-vm --help` prints usage.

Acceptance: baseline saved, gates pass or their failures are recorded. Rollback:
nothing to roll back.

### Stage 1 — flake-parts, import-tree, named module graph `[tier: med]`

Scope: `flake.nix`, `flake.lock`, new `hosts/default.nix`,
`modules/e2e/desktop-tests.nix`; `git mv` of `modules/e2e.nix` to
`modules/desktop/e2e-injection.nix`, `modules/vm-variant.nix` to
`modules/desktop/vm-variant.nix`, `modules/vm-layer.nix` to
`modules/e2e/vm-layer.nix`, `modules/paperwm.nix` to
`modules/gnome/paperwm.nix`. Depends on: stage 0. One or two commits.

- [ ] Add inputs `flake-parts` (with `inputs.nixpkgs-lib.follows = "nixpkgs"`)
      and `import-tree` (`github:denful/import-tree`); `nix flake lock` adds two
      lock nodes.
- [ ] `flake.nix` becomes inputs plus
      `flake-parts.lib.mkFlake { inherit     inputs; } { systems = [ "x86_64-linux" ]; imports = [     inputs.flake-parts.flakeModules.modules (inputs.import-tree ./modules)     ./hosts ]; }`.
      No `let` block, no package names.
- [ ] Each moved file becomes a flake-parts module wrapping its previous body as
      `flake.modules.nixos.<name>`; no aspect registration yet. `vm-variant`
      imports `config.flake.modules.nixos.vm-layer`.
- [ ] `hosts/default.nix` defines the host list,
      `flake.modules.nixos."host-${name}"` as
      `{ imports = [ ./${name}     e2e-injection paperwm vm-variant inlineShared ]; }`,
      where `inlineShared` is the former inline block moved verbatim into a
      `let`, and `flake.nixosConfigurations`. The host bodies
      `hosts/*/default.nix` stay plain NixOS modules in this stage.
- [ ] `desktop-tests.nix` defines the four packages in `perSystem` per the
      conventions.
- [ ] Update the moved-path references in `docs/e2e-testing.md`,
      `tests/desktop.py`, and `docs/tiling-windows.md`.
- [ ] `nix flake show --all-systems` lists the six original outputs;
      `nix     eval .#modules.nixos --apply builtins.attrNames` lists
      `e2e-injection`, `paperwm`, `vm-layer`, `vm-variant`, `host-hardy`,
      `host-gauss`. Note in the ticket which empty standard attributes
      flake-parts adds.

Acceptance: `just check` on `gauss` and on `galois`; fingerprint `semantic`
lines unchanged; `just e2e-vm --no-test --host gauss` still resolves
`run-gauss-vm`. Rollback: revert the stage's commits.

### Stage 2 — features and aspects `[tier: med]`

Scope: every file under `modules/base`, `modules/desktop`, `modules/gnome`;
`hosts/default.nix` composes `[ ./${name} base desktop gnome ]` and loses
`inlineShared`; the host bodies shrink as lines move out. Depends on: stage 1.
Three commits, one per aspect, in this order:

- [ ] `base`: the eight features with their registrations; `inlineShared`
      dissolves (packages, revision, boot retention, `nh`, Tailscale go to their
      features; MIME defaults wait for `brave`). Host composition becomes
      `[ ./${name} e2e-injection paperwm vm-variant base ]` with the MIME block
      kept inline until the next commit. Herdr resolves through `inputs.herdr`
      inside the flake-parts module.
- [ ] `desktop`: `keyd`, `ghostty`, `brave`, `vicinae`, `onepassword`;
      `e2e-injection` and `vm-variant` register into `desktop`. Host composition
      becomes `[ ./${name} paperwm base desktop ]`. Hardy and gauss keyboard,
      group, and capability declarations remain in the host bodies.
- [ ] `gnome`: `gnome-session` with the disjoint-keys assertion (written against
      `config.programs.dconf.profiles.user.databases`; prove it fires once by
      temporarily duplicating a key locally, not committed),
      `gnome-keybindings`, `keyd-gnome-extension`; `paperwm` registers into
      `gnome` and gains the winprops database. Host composition becomes
      `[ ./${name} base desktop gnome ]`.
- [ ] After the last commit: `just e2e-vm --host hardy` and `--host gauss` match
      the stage 0 results.

Acceptance per commit: `just check`; fingerprint `semantic` diff against the
baseline shows only the moves the commit message names (the gauss Ghostty config
path is the one expected value change). Acceptance for the stage: both VM suites
match baseline. Rollback: revert the offending commit.

### Stage 3 — thin hosts `[tier: med]`

Scope: `hosts/hardy/default.nix`, `hosts/gauss/default.nix`,
`hosts/default.nix`, `AGENTS.md`. Depends on: stage 2.

- [ ] Rewrite each host body as a flake-parts module defining
      `flake.modules.nixos.host-<name>` with
      `imports = [     ./hardware-configuration.nix ]` plus `base`, `desktop`,
      `gnome` from `config.flake.modules.nixos`, then `networking.hostName`,
      `system.stateVersion`, and the exceptions with their comments.
      `hosts/default.nix` keeps only the host list, the directory imports, and
      `flake.nixosConfigurations`.
- [ ] Every remaining line in a host file is identity, hardware, or an exception
      listed in the ticket. Anything else goes back to stage 2.
- [ ] `AGENTS.md` layout: `hosts/default.nix` is the inventory and every other
      entry is one machine; `modules/` is auto-imported by import-tree, one
      feature per file, grouped by aspect directory.
- [ ] `just plan` on both NixOS hosts builds and shows the closure diff (no
      apply); `just e2e-vm --host hardy`, `--host gauss`,
      `--no-test --host     gauss`, `just omarchy-vm --help`, and
      `just current-state` behave as in stage 0.

Acceptance: VM suites match baseline, gates pass, fingerprint `semantic` diff
explained. Rollback: revert.

### Stage 4 — documentation `[tier: med]`

Scope: new `docs/module-architecture.md`; edits to `docs/README.md`,
`docs/file-layout.md`, `docs/workspace.md`, `docs/e2e-testing.md`,
`docs/tiling-windows.md`; a checkpoint in the research note. Depends on:
stage 3.

- [ ] `docs/module-architecture.md` covers: the topology; how flake-parts and
      import-tree compose the flake (`mkFlake`, `systems`, `perSystem`, the
      `modules` extras, the underscore ignore rule); how a feature file is
      written and registered into an aspect; how hosts select aspects or
      features and where exceptions live; adding a feature; adding a host;
      adding a second desktop as a sibling of `gnome`; the import-tree decision
      and its tradeoff; the dconf and tmpfiles ownership rules; how output
      compatibility is checked with the fingerprint script.
- [ ] `docs/README.md` indexes it under Working Here; `docs/file-layout.md`
      shows `hosts/` and `modules/`; `docs/workspace.md` names the fingerprint
      script beside the quality gate.
- [ ] `thoughts/research/module-architecture.md` gets a dated checkpoint
      pointing at the doc; Daniel decides whether the rest stays.

Acceptance: `just check` passes; every link resolves. Rollback: revert.

### Stage 5 — final verification and closeout `[tier: high]`

Depends on: stage 4. Run from `gauss`; use SSH for `hardy`.

- [ ] `just check` on `gauss`, `hardy`, and `galois`.
- [ ] `scripts/output-fingerprint.sh WORKTREE` versus `00-baseline.txt`: the six
      output names present, both toplevels and four packages evaluate,
      `semantic` differences all explained in the ticket.
- [ ] `nix build .#nixosConfigurations.hardy.config.system.build.toplevel` and
      the gauss equivalent succeed on `gauss`.
- [ ] `just plan` on both NixOS hosts; no apply.
- [ ] `just e2e-vm --host hardy` and `just e2e-vm --host gauss` pass at the
      stage 0 level; `just e2e-vm --no-test --host hardy` and `--host gauss`
      resolve their runners; `just omarchy-vm --help`; `just current-state`.
- [ ] `nix flake show --all-systems` and `nix flake check` on `galois`.
- [ ] `git status` clean; no `result*` links or `/tmp` artifacts tracked.
- [ ] Set `Status: done`; move the backlog item to `## Closed` with the outcome
      stated as clarity and a working system, not runtime improvement; push the
      branch; report its state to Daniel and stop. Merging, applying, and the
      plan's disposition are Daniel's.
