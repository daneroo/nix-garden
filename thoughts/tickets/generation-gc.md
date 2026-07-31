# Generation GC

Named for what it reclaims -- Nix store space -- to stay distinct from
bootloader entry retention, which is capped separately and reclaims nothing. The
boot side is settled and documented in
[workspace](../../docs/workspace.md#boot-generations).

Hardy and Gauss accumulate NixOS generations because no automatic cleanup is
enabled. The flake already enables `programs.nh`, but its pinned cleanup module
defaults to disabled and exposes `clean.enable`, `clean.dates`, and
`clean.extraArgs`. Observed 2026-07-30: gauss at 38 generations and a 48G store,
hardy at 32 and 52G.

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
- Choose the count alongside the bootloader cap, currently 20. Keeping fewer
  generations than the boot menu offers leaves stale entries; keeping far more
  leaves rollback targets that cannot be selected at boot.
- Decide whether to consume systemd's boot-assessment state. Neither this
  mechanism nor the bootloader can currently express the requirement we actually
  have -- retain a number of _known-bootable_ generations.
  `systemd-boot-builder` selects with a plain recency slice,
  `configurations[-configurationLimit:]`, and `nixos-rebuild switch` never
  reboots, so most entries have never been booted. Gauss averages 5.4
  generations per boot against hardy's 1.9, so a cap of N holds roughly N/5
  boots of real depth on gauss.

  Boot counting is the only thing that records the answer, and it is now
  enabled: blessing an entry removes its counter suffix, so the ESP
  distinguishes known good (`nixos-<hash>.conf`) from never tried (`+3`) and
  exhausted (`+0-3`), and the builder preserves that state across rebuilds.
  Nothing reads it. "Keep the newest N plus the newest M blessed" is therefore
  implementable against state already on disk -- worth an upstream feature
  request or a builder override before writing anything bespoke.

  The signal is noisy in both directions, which any policy built on it has to
  tolerate: a generation that boots cleanly into a broken desktop is blessed
  anyway, and three interrupted boots burn a good entry's counter as surely as
  three real failures.

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

## Harvest

At closeout, extend the Boot Generations section of
[workspace](../../docs/workspace.md#boot-generations) rather than starting a new
page: the two halves are one subject, and keeping them together is what stops
the boot-entry and store-reclamation limits being confused again. Consider
whether the combined section has outgrown `workspace.md` by then.
