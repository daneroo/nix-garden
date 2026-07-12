# repository-command-surface — Rationalize Repository Tooling

Decide and document the smallest coherent command surface for developing,
checking, bootstrapping, and applying nix-garden across macOS and NixOS.

## Why This Needs a Decision

The repository currently spreads responsibilities across several mechanisms:

- `Justfile` exposes memorable user-facing commands and composes operations.
- `scripts/` contains shell implementations for bootstrap and quality checks.
- `bunx` supplies Markdown formatting and linting tools.
- The NixOS configuration installs tools needed on `hardy`.
- There is no development shell defining a portable contributor environment.

Interim choice: use Bun and Prosodio-compatible Markdown tools so the quality
gate works on macOS and on `hardy`, where the flake installs Bun. This is
provisional until this ticket compares it with a Nix-native toolchain.

Each mechanism is reasonable in isolation, but their boundaries have not been
chosen explicitly. Without a policy, commands may be duplicated, wrappers may
multiply, and macOS development may accidentally rely on tools absent from a
freshly rebuilt `hardy`.

## Questions

- Is `Justfile` the canonical repository command surface, with underlying tools
  treated as implementation details?
- Which operations deserve a script because they contain real shell logic, and
  which should remain a direct Just recipe?
- Should `scripts/` contain only reusable/testable logic rather than one-line
  command wrappers?
- Should JavaScript tooling have a minimal `package.json` with scripts and
  dependencies, or is `bunx` sufficient at this scale?
- Should `flake.nix` expose a `devShell` containing the complete development
  toolchain? If so, how should macOS support relate to the Linux-only host
  configuration?
- Which tools belong in `environment.systemPackages` because the rebuilt machine
  needs them, versus only in a development environment?
- How should CI invoke the same quality gate without duplicating its definition?
- Should repository editor recommendations mirror the formatter and linter used
  by the CLI, and how much editor-specific configuration belongs in the repo?
- What is the bootstrap guarantee before the normal command surface is
  available?

## Desired Outcome

- One documented entry point for common development and operational commands.
- Clear criteria for direct recipes, scripts, package scripts, dev-shell tools,
  and host-installed packages.
- The same quality-gate behavior on supported development machines and CI.
- No unnecessary wrapper scripts or duplicated command definitions.
- A fresh `hardy` rebuild contains everything required for its intended local
  workflow.

## Evidence to Gather

- Exercise the current commands on macOS and rebuilt `hardy`.
- Preserve the observed glob result: `"**/*.md" "*.md"` missed nested design,
  plan, and ticket files in nix-garden; do not reduce coverage based only on
  expected glob semantics.
- Note which commands require network access or populate external caches.
- Compare a minimal `devShell` with the current host-package-plus-Bun approach.
- Compare lightweight editor recommendations with Prosodio's format-on-save and
  Markdown diagnostics setup; keep the command-line gate authoritative.
- Check whether Prosodio conventions are useful precedent or
  application-specific coupling.
