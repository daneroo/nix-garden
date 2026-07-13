# flake-parts, import-tree, and Wrapped Modules

Research note, 2026-07-12, supporting `module-architecture` and informing
`nix-formatting` and `development-environments`. What the newer refactor/reuse
patterns buy, what they cost, and when this repo should adopt each.

## flake-parts — the module system applied to the flake itself

Plain flakes are untyped attribute sets built by hand; repetition across systems
(`forAllSystems`) and outputs is manual. flake-parts runs the same module system
NixOS uses, but over _flake outputs_: `imports`, options, and merging for
flake.nix, plus `perSystem` to define devShells, packages, formatter, and checks
once for every system.

- **Buys**: composition (split the flake into focused modules that merge); an
  ecosystem of plug-in flakeModules — treefmt-nix, devshell, pre-commit-hooks,
  hercules-ci — that slot in with one `imports` line; option-checked outputs
  instead of typo'd attr paths.
- **Costs**: one more abstraction while still learning Nix; deeper error traces;
  pure overhead for today's 44-line single-host flake.
- **Adoption trigger for this repo — likely sooner than "second host"**: the
  `nix-formatting` ticket plus a macOS-capable devShell means defining
  formatter/checks/devShells for both `x86_64-linux` and `aarch64-darwin`. That
  cross-system repetition is exactly `perSystem`'s job, and treefmt-nix (a
  strong answer to the formatting ticket) is most pleasant as a flakeModule.
  `nixosConfigurations` remain defined the same way inside it.
- flake-utils is the older, thinner alternative; largely superseded — if
  adopting anything here, adopt flake-parts.

## import-tree and the Dendritic pattern

import-tree auto-imports every `.nix` file under a directory as a module. The
"Dendritic" pattern builds on it: organize by _feature/aspect_, not by host —
each file is a flake-parts module that can contribute config to several hosts
(and to Home Manager and NixOS at once), and wiring is implicit.

- **Buys**: zero import plumbing; feature cohesion (everything about "tailscale"
  or "niri" in one file across all machines).
- **Costs**: implicit structure — discovering _why_ a host has some setting
  means understanding the whole convention; magic before fundamentals.
- **Verdict**: the right time is 3+ hosts, when module wiring is a measured
  friction. Watch, don't adopt. Matches the design doc's existing caution.

## Wrapped programs (wrapper modules)

The pattern from the referenced Vimjoyer material: instead of a module writing
dotfiles into a user environment, build a package that _wraps the program with
its configuration baked in_ (`makeWrapper`/`symlinkJoin` by hand, or
wrapper-manager as the framework). Program + config becomes one derivation.

- **Buys**: portability — the same wrapped editor/terminal with its keybindings
  runs via `nix run` on NixOS, on `galois` (macOS), in a devshell, with no Home
  Manager activation and no global state. Self-contained units are also
  independently testable and composable into any host.
- **Costs**: works best for programs configurable via flags/env/XDG paths;
  config edits require a rebuild (worse inner loop than editing a symlinked
  dotfile); much smaller ecosystem than Home Manager's modules.
- **Fit here**: directly serves the cross-platform keybinding goal — a wrapped
  terminal or editor is the _same artifact_ on `hardy` and the Mac, making
  binding parity testable instead of aspirational. Complement to Home Manager,
  not a replacement: HM owns the desktop session tree (compositor, session
  services); wrapped programs own portable per-tool units.

## Suggested Sequence

1. Now: nothing. The thin flake is correct for one host.
2. With `nix-formatting` + a devShell (especially macOS): adopt flake-parts +
   treefmt-nix; that is the first real consumer of `perSystem`.
3. When desktop work starts: pilot _one_ wrapped program (terminal or editor)
   and run it on both `hardy` and `galois` as the keybinding-parity probe.
4. At 3+ hosts: revisit import-tree/Dendritic if host/feature wiring has become
   demonstrable friction.

## Sources

- [flake-parts](https://flake.parts/)
- [treefmt-nix](https://github.com/numtide/treefmt-nix)
- [import-tree](https://github.com/vic/import-tree)
- [wrapper-manager](https://github.com/viperML/wrapper-manager)
- [Vimjoyer: flake-parts and wrapped modules](https://www.vimjoyer.com/vid79-parts-wrapped)
  (already in the design doc's references)
