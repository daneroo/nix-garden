# Rationalize Current State

`just current-state` reports one machine. Answering the question it exists for
-- "is the fleet converged?" -- currently means three manual invocations and
eyeballing three strings:

```text
galois  nix: lock/e2587ca                     git: main/ffe895d-dirty
gauss   nix: 26.11.20260723.e2587ca@ffe895d   git: main/ffe895d
hardy   nix: 26.11.20260723.e2587ca@ffe895d   git: main/ffe895d
```

Two problems. The row is redundant: on a converged host the nixpkgs revision and
the nix-garden revision each appear twice, and the NixOS version string already
ends in the nixpkgs revision. And the comparison -- the actual point -- is left
entirely to the reader.

## Constraint

Only `galois` can reach `hardy` and `gauss`; the hosts cannot reach each other
or `galois`. So a fleet view is complete from `galois` and partial everywhere
else. This is current topology, not a law: both hosts already run Tailscale, so
symmetry is an ACL and key question owned by the `tailscale-reconciliation` and
`remote-access` backlog items. The design must not assume `galois` is the
controller -- that assumption breaks the day the daily driver changes.

## Where the row comes from

The `nix:` field is not one kind of fact. On NixOS it joins
`nixos-version --json` to `system.configurationRevision`, which `flake.nix`
stamps as `self.rev or self.dirtyRev or "dirty"`. Off NixOS there is no running
system, so `scripts/current-state.sh` substitutes the root nixpkgs pin from
`flake.lock` and renders `lock/REV` instead.

Three consequences for any reformat:

- The stamp has three shapes: a clean revision, `<rev>-dirty`, or the literal
  `dirty`. A generation built from a dirty tree is not reproducible from any
  commit -- drift worth stating outright rather than a suffix to squint at.
- A `galois` row and a host row are different claims. One reports a running
  system; the other reports only what the checkout would build. Rendering them
  identically invites misreading them as comparable.
- Every dirty build yields a different stamp and therefore a different toplevel,
  so dirty applies churn the closure for no other reason.

## Decisions

- Name it for the question it answers. `just state` reads better than
  `current-state` or a plural, with local-only as the degenerate case rather
  than a separate recipe. Decide whether a `--local` fast path is worth it once
  the fan-out cost is known.
- Define fleet membership. Proposed: the declared `nixosConfigurations` plus
  whichever machine is running the command. `galois` is not and will not be a
  `nixosConfiguration` while it is a Mac.
- Pick one source of truth for the host list. It is currently duplicated between
  `blessed_hosts` in the `Justfile` and `hosts` in `flake.nix`;
  `nix eval .#nixosConfigurations --apply builtins.attrNames` would collapse
  them and stay correct when a host is added.
- Report unreachability as a row, not an error, so the command is honest from
  any machine and needs no change if the topology opens up later.
- Decide what counts as drift and how loudly to say it: running generation
  behind the checkout, checkout behind `origin/main`, dirty working tree, hosts
  on differing nixpkgs revisions. A converged fleet should collapse to roughly
  one line.
- Decide what the row still needs to carry once a verdict line exists, and
  whether the `--verbose` diagram survives the reformat or moves to `--help`.
- Keep `scripts/current-state.sh` as the single-host row producer if the
  aggregator stays thin; it already degrades correctly off NixOS to `lock/REV`.

## Acceptance

- One command reports every reachable member of the fleet plus a verdict, and
  states plainly which members it could not reach.
- Running it on a host rather than `galois` produces a correct, partial answer
  rather than an error.
- A converged fleet is obvious at a glance; drift names the machine, the
  dimension that drifted, and the direction.
- Remote invocation does not require `just` on the remote, and a sleeping host
  costs a short timeout rather than a hung command.
- The host list has exactly one definition in the repository.

## Scope

This is the "current state" slice of [host-inventory](host-inventory.md); build
the small command and leave that ticket to own hardware, roles, and criticality.
The stray recipe echo above each row is already fixed by prefixing the recipe
with `@`.
