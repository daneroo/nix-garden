# nix-formatting — Choose and Integrate Nix Formatting

Priority: high

Choose the canonical formatter for Nix source, define write and check commands,
and make the formatting check part of the repository quality gate.

## Context

Prettier and markdownlint now cover Markdown and other supported text formats,
but they do not own `.nix` files. Nix formatting has multiple tools, evolving
names and styles, and integration choices involving the flake formatter output,
development environments, editor support, and CI.

The repository primarily targets NixOS on `hardy`. Development also currently
happens on macOS, where the chosen formatter may not be available or executable
through the same mechanism.

## Questions

- Which formatter and style should be canonical for this repository?
- Should `flake.nix` expose `formatter.<system>` so `nix fmt` is the standard
  write command?
- What command should verify formatting without writing files?
- Should the check operate on tracked Nix files, the whole repository, or a
  formatter-managed file set?
- How should the check join `just pre-commit` without duplicating formatter
  selection or file discovery?
- Should editor formatting invoke `nix fmt`, the formatter binary, or another
  repository command?
- Does introducing a formatter justify a `devShell`, tree-wide formatter
  orchestrator, or neither?
- How should formatter-version changes and resulting mechanical rewrites be
  reviewed?

## Required Outcome

- One documented formatter and style for `.nix` files.
- A repository command that formats Nix files.
- A non-writing formatting check in the required quality gate.
- Formatter selection and version derived from the pinned Nix inputs rather than
  an unrelated machine-global installation.
- Existing Nix files normalized once in a clearly mechanical change.

## Stretch Goal: macOS

Make the same repository formatting commands work on macOS as well as NixOS. Do
not block the core NixOS integration if the selected formatter or flake output
cannot yet execute on macOS; document the limitation and a safe alternative.

Investigate whether the flake should expose a supported Darwin system, whether
the formatter package is available there, and whether doing so would
unnecessarily couple host configuration with development-tool outputs.
