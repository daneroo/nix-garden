# Generation Retention

Hardy and Gauss accumulate NixOS generations because no automatic cleanup is
enabled. The flake already enables `programs.nh`, but its pinned cleanup module
defaults to disabled and exposes `clean.enable`, `clean.dates`, and
`clean.extraArgs`.

Choose and deploy a conservative automatic-retention policy. Preserve enough
recent generations for useful rollback while removing old profile roots so
unreachable store paths can be collected.

## Decisions

- Compare `programs.nh.clean` with native `nix.gc`; prefer the smallest
  mechanism whose cleanup scope is explicit.
- Choose both an age window and a minimum generation count rather than deleting
  every non-current generation.
- Decide whether user profiles, Home Manager profiles, result roots, and direnv
  roots belong in scope.
- Choose a schedule and confirm what happens when a sleeping host misses it.
- Keep generation retention separate from replacing `just plan` or `just apply`
  with `nh`.

## Acceptance

- Record generation counts and relevant store usage on Hardy and Gauss before
  cleanup.
- Review the exact roots and generations the selected mechanism can remove.
- Deploy through the normal host-specific plan, approval, apply, and
  reconciliation boundary.
- Verify the active generation remains protected and the intended rollback
  window remains available on both hosts.
- Record reclaimed space, timer health, failure behavior, and the manual
  recovery command in durable documentation.
