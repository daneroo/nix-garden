# Module Architecture

The flake is composed with flake-parts, import-tree, and Dendritic feature
modules. Three questions each have one answer in one file: what a feature owns
(its file under `modules/`), what a host selects (its file under `hosts/`), and
what the flake publishes (`hosts/default.nix` for hosts,
`modules/e2e/desktop-tests.nix` for packages).

## Topology

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
tests/                           the VM suite body; unchanged by the architecture
```

## How the flake is composed

`flake.nix` holds the inputs and one call:
`flake-parts.lib.mkFlake { inherit inputs; } { systems; imports; }`. Nothing
else lives there.

- `systems = [ "x86_64-linux" ]`. No output is indexed by another system; adding
  `aarch64-darwin` is the `nix-formatting` item's concern.
- `inputs.flake-parts.flakeModules.modules` provides the class-typed
  `flake.modules.<class>.<name>` option. Every NixOS module this repository
  publishes is `flake.modules.nixos.<name>`; flake-parts stamps each with
  `_class = "nixos"` so importing one into the wrong module class fails. Nix
  reports the output as unknown or unchecked in `nix flake show` and
  `nix flake check`; that is cosmetic. List the modules with
  `nix eval .#modules.nixos --apply builtins.attrNames`.
- `inputs.import-tree ./modules` imports every `.nix` file under `modules/` as a
  flake-parts module, except paths containing `/_`. A file is live the moment it
  exists; a file that is not ready gets a leading underscore.
- `./hosts` is imported explicitly, so `hosts/default.nix` decides which host
  directories exist and the generated `hardware-configuration.nix` files are
  never auto-imported.
- `perSystem` is used once, in `modules/e2e/desktop-tests.nix`. It replaces the
  default `pkgs` (nixpkgs' `legacyPackages`, which has no `allowUnfree`) with
  `import inputs.nixpkgs { inherit system; config.allowUnfree = true; }` so test
  tooling may be unfree, and defines the four packages.

## Features and aspects

A feature file defines exactly one named module and registers it into the aspect
its directory names:

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

- The module may be a function `{ pkgs, lib, ... }: { ... }` when it needs NixOS
  module arguments; flake inputs come from the outer `inputs` argument.
- Features reference each other only through `config.flake.modules.nixos`, never
  by path.
- An aspect is itself a module whose `imports` the features fill in: `base`
  (platform), `desktop` (compositor-agnostic applications and input), `gnome`
  (the session). `e2e/` is the exception: `vm-layer` is published by name and
  never registered, because importing it into a real host would grant
  passwordless graphical login.
- Comments move with the configuration they explain. Shared knowledge lands in
  the feature once; host-only knowledge stays in the host file.

## Hosts

`hosts/<name>/default.nix` defines `flake.modules.nixos.host-<name>`: the
hardware file, the three aspects, `networking.hostName`, `system.stateVersion`,
and that host's exceptions, each with a comment naming why it is host-specific.
A host needing a subset imports individual features instead of an aspect.
`hosts/default.nix` lists the hosts, imports their directories, and defines
`nixosConfigurations` with
`nixpkgs.lib.nixosSystem { system = "x86_64-linux"; modules = [ host ]; }`. The
VM suites test the same `host-<name>` module plus `vm-layer`.

The `Justfile` and `scripts/e2e-vm.sh` keep their own `blessed_hosts` copies of
the host list.

## Adding things

- A feature: create `modules/<aspect>/<name>.nix` with the shape above. It is
  live on both hosts as soon as the file exists; run `just check`.
- A host: add the name to `hosts/default.nix`, create `hosts/<name>/` with the
  generated `hardware-configuration.nix` and a `default.nix` that imports the
  aspects it wants, then add the name to the `blessed_hosts` lists.
- A second desktop: create `modules/<desktop>/` whose files register into
  `flake.modules.nixos.<desktop>`, and have a host import it instead of `gnome`.
  `desktop` stays compositor-agnostic so both sessions share it.

## Ownership rules

- dconf: `programs.dconf.profiles.user.databases` compiles each list element
  into its own database and looks keys up first-wins in profile order. Features
  contribute their own databases with disjoint key paths; `gnome-session` owns
  `org/gnome/shell` and asserts at evaluation time that no key path is defined
  by two databases.
- tmpfiles: systemd-tmpfiles creates parents before children regardless of line
  order, materialises missing parents as root, and refuses to descend an
  ownership change. `user-daniel` owns the XDG skeleton (`.config`, `.local`,
  `.local/share`) and each feature owns the subdirectory and `L+` lines for its
  own files. All of it is a stopgap that `home-config-ownership` deletes.
- List options concatenate in module-system order, which is not the literal
  top-level order. Reordering `environment.systemPackages` changes the
  `system-path` derivation without changing behavior.

## The import-tree decision

Full Dendritic wiring was chosen over explicit index files. No file lists what
exists, a stray `.nix` under `modules/` is live configuration, and files not
ready must carry a leading underscore. The aspect directories and the
one-feature-per-file rule carry discoverability instead, and the module list is
one `nix eval` away. Hosts stay explicit because an inventory was a stated goal.

## Checking output compatibility

`scripts/output-fingerprint.sh [REV | WORKTREE]` evaluates a revision as a
`path:` flake, where `system.configurationRevision` is the literal `dirty`, and
prints the output names, the toplevel and package derivation paths, and a
`semantic` section: an order-independent list of the configuration values this
repository owns. Diff two runs to see what a refactor dropped or renamed:

```bash
diff <(scripts/output-fingerprint.sh main) <(scripts/output-fingerprint.sh WORKTREE)
```

Derivation paths are informational. The `environment.etc` entries whose values
are store paths built from `system-path` or `tmpfiles.d` change whenever list
order changes; the sorted `systemPackages` and `tmpfiles` lists are the
behavior. `nix-diff` explains any remaining derivation difference.
