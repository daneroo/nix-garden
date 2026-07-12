# Migrate to nix-garden

Status: planned

Goal: make `nix-garden` the live fleet repository while preserving the complete
history and recoverability of both repositories.

Routing: the coordinating agent owns this high-risk Git migration. A lower-power
subagent may audit inventories, links, and final history, but must not move,
delete, merge, push, or archive repositories.

## Protect Both Sources

- [ ] Commit the current nix-hardy vision/backlog changes and verify its gate.
- [ ] Review and separately commit the existing `nix-garden/clan/README.md`
      change; do not absorb it silently into migration work.
- [ ] Confirm both worktrees are clean and record HEADs, branches, and remotes.
- [ ] Create explicit local recovery refs for both pre-migration heads.
- [ ] Inventory ignored/untracked nix-garden artifacts; do not move caches,
      generated ISOs, or unknown local state by accident.
- [ ] Do not import the public test-VM password hash into the live root; the
      test VM is gone, so no live credential rotation is required.

## Archive the Earlier Tree

- [ ] In nix-garden, move its tracked experiment tree with `git mv` under a
      clearly named `legacy/` directory, preserving history.
- [ ] Keep a short legacy README stating why the material remains and that it is
      reference evidence, not the live architecture.
- [ ] Commit the archive move alone.

## Import the Live Repository

- [ ] Add and fetch nix-hardy as a temporary local Git remote.
- [ ] Merge its `main` with unrelated histories allowed, placing live files at
      the nix-garden root and resolving conflicts deliberately.
- [ ] Replace temporary `nix-hardy` repository references with `nix-garden`;
      retain `hardy` only as the host name.
- [ ] Keep nix-garden's existing `origin` as the canonical remote.
- [ ] Commit post-merge naming and link cleanup separately from the merge.

## Verify and Cut Over

- [ ] Run the complete nix-garden quality gate and inspect flake outputs.
- [ ] Verify both histories and representative renamed files remain reachable.
- [ ] Audit links, executable bits, ignored files, and instructions.
- [ ] Clone the consolidated remote fresh and repeat checks.
- [ ] Push nix-garden only after local validation.
- [ ] Archive `daneroo/nix-hardy` only after the pushed nix-garden clone is
      proven; do not delete either local source during this plan.
