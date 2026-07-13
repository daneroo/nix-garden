# Flake Pinning — Intent, Resolution, and the Missing Layer

Research note, 2026-07-12, supporting `flake-pinning` (high priority). Question:
pinning is right, but the _declarative intent_ ("Node LTS", "nixpkgs stable")
should be captured in the repo and automated tooling should resolve intent →
exact pin. Where is that layer in Nix?

## The Three-Part Model

Every mature package ecosystem separates:

1. **Manifest (intent)** — `"node": "^24"` in `package.json`.
2. **Lockfile (resolution)** — exact versions + hashes.
3. **Resolver** — the tool that turns 1 into 2, re-runnable on demand.

Nix's standings: the **lockfile is world-class** (`flake.lock` pins git revs and
content hashes transitively — stronger than npm's integrity fields). The
**intent language is deliberately weak**: a flake input can express only "this
URL/branch/tag", no ranges, no "LTS", no constraints. And the **resolver**
(`nix flake update`) can only say "tip of the ref". The observation that a layer
is missing is correct — and it is missing _by design_, which matters for where
to add it.

## Why Nix Has No Version Solver

npm/cargo/pip resolve dependencies per-project with a constraint solver. Nixpkgs
instead resolves once, centrally: it is a **coordinated snapshot** — one
coherent set of ~100k packages whose versions are chosen by maintainers and
validated by Hydra CI. Channel branches like `nixos-unstable` only advance when
the test suite passes, so _the branch itself is resolver output_.

What that buys: coherence (everything in a snapshot is built together), binary
cache hits, and no per-project dependency hell. What it costs: "I want node
24.xx.yy precisely" cross-cuts the model — a snapshot has _the_ node 24 it has.
The intent layer therefore cannot live inside the core; it gets layered on top,
which is exactly why there are "a lot of pinners".

## The Gap-Fillers, Categorized

- **Semver for flakes:**
  [FlakeHub](https://docs.determinate.systems/flakehub/concepts/semver/)
  (Determinate Systems) adds real SemVer ranges to flake inputs
  (`https://flakehub.com/f/NixOS/nixpkgs/0.2505.*`), with tagged and rolling
  release schemes. A company building a product here is strong validation that
  the layer is missing — the trade is a vendor/service dependency in the
  resolution path.
- **Version → revision search:**
  [nixhub.io](https://www.nixhub.io/packages/nodejs) and
  [lazamar's nix-versions](https://lazamar.co.uk/nix-versions/) map "package X
  version Y" to the nixpkgs revision that carries it.
  [Devbox](https://www.jetify.com/docs/devbox/guides/pinning-packages) (Jetify)
  productizes the whole intent layer: `nodejs@24` in `devbox.json`, resolved
  per-package to pinned nixpkgs revisions — the closest thing to `package.json`
  semantics on Nix today, aimed at dev environments rather than system config.
- **Resolver automation:**
  [update-flake-lock](https://github.com/DeterminateSystems/update-flake-lock)
  (GitHub Action) and Renovate (native `flake.lock` support) turn resolution
  into scheduled PRs. Tag-pinned inputs like Herdr can be bumped by Renovate
  regex rules watching upstream releases.
- **Non-flake pinners** (niv, npins): mostly pre-flake ergonomics for the _lock_
  layer, not semantic intent — evidence of churn, but a different gap.

## The Reframe: In Nix, the Resolver Is a CI Loop

SemVer is a social promise that an update is compatible; it is routinely wrong
even in JS-land. Nix can do better than trusting the promise, because
**intent-satisfaction is checkable by building**: a candidate pin either builds
the hosts, passes the VM smoke tests, and shows a clean `diff-closures`, or it
does not.

So express intent as _policy plus gate_, and let automation converge:

- **Desired**: "newest rev of `nixos-unstable` that passes this repo's gate"
  (later, per-host: stable branch for load-bearing hosts).
- **Actual**: the current `flake.lock`.
- **Converge**: a scheduled bot PR (`update-flake-lock`/Renovate) runs
  `nix flake update`, CI builds the toplevels and checks, the human reviews the
  closure diff, merge lands the new pin.

This is [reconciliation](../../docs/reconciliation.md) applied to the lockfile,
and it degrades gracefully: until CI exists, `just plan`'s
update-prompt-plus-diff _is_ the manual resolver run.

## Policy Recommendations for This Repo

- **Intent encoding**: branch choice per input (`nixos-unstable` now); tags for
  release-disciplined inputs (Herdr `v0.7.3`); package-level majors via nixpkgs
  attrs (`nodejs_24` — major is intent, patch floats with the snapshot, Hydra is
  the patch-resolver).
- **Exact-version needs** (the true "node 24.xx.yy"): first ask whether the need
  is real (usually the intent is "major 24, tested"); if it is, add a second
  pinned `nixpkgs-node` input at a revision found via nixhub/lazamar, scoped to
  that package. Avoid hand-rolled version overlays — they silently opt out of
  the binary cache and Hydra testing.
- **Update scope**: `nix flake update <input>` for surgical bumps;
  `--commit-lock-file` so every resolution is one reviewable commit.
- **Automation**: adopt `update-flake-lock` or Renovate once CI builds the
  `hardy` toplevel (review step 3–4); weekly cadence, small diffs.
- **FlakeHub**: track as the ecosystem's semver experiment; adopt only if the
  vendor dependency is acceptable — the CI-loop resolver above provides most of
  the value vendor-free.
- **Devbox lesson**: for per-project dev shells (the `nixvana` lessons), its
  intent model is worth copying even if the tool is not adopted.

## Done Criteria for the Ticket

- Intent per input written next to the input (comment or doc): what it tracks,
  why, and its update cadence.
- One command / bot performs resolution; a human reviews only the diff.
- The gate (build + check, later VM tests) is what "compatible" means here — not
  a version range.

## Sources

- [FlakeHub SemVer concepts](https://docs.determinate.systems/flakehub/concepts/semver/)
- [Introducing FlakeHub](https://determinate.systems/blog/introducing-flakehub/)
- [Devbox: pinning package versions](https://www.jetify.com/docs/devbox/guides/pinning-packages)
- [nixhub.io](https://www.nixhub.io/packages/nodejs)
- [lazamar nixpkgs version search](https://lazamar.co.uk/nix-versions/)
- [update-flake-lock action](https://github.com/DeterminateSystems/update-flake-lock)
