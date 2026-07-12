# Migrate to nix-garden

Status: active

Goal: make `nix-garden` the live fleet repository while preserving the complete
history and recoverability of both repositories.

Routing: the coordinating agent owns this high-risk Git migration. A lower-power
subagent may audit inventories, links, and final history, but must not move,
delete, merge, push, or archive repositories.

## Protect Both Sources

- [x] Commit the current nix-hardy vision/backlog changes and verify its gate.
- [x] Review and separately commit the existing `nix-garden/clan/README.md`
      change; do not absorb it silently into migration work.
- [x] Confirm both worktrees are clean and record HEADs, branches, and remotes.
- [x] Create explicit local recovery refs for both pre-migration heads.
- [x] Inventory ignored/untracked nix-garden artifacts; do not move caches,
      generated ISOs, or unknown local state by accident.
- [x] Do not import the public test-VM password hash into the live root; the
      test VM is gone, so no live credential rotation is required.

## Archive the Earlier Tree

- [x] In nix-garden, move its tracked experiment tree with `git mv` under a
      clearly named `legacy/` directory, preserving history.
- [x] Keep a short legacy README stating why the material remains and that it is
      reference evidence, not the live architecture.
- [x] Commit the archive move alone.

## Import the Live Repository

- [x] Add and fetch nix-hardy as a temporary local Git remote.
- [x] Merge its `main` with unrelated histories allowed, placing live files at
      the nix-garden root and resolving conflicts deliberately.
- [x] Replace temporary `nix-hardy` repository references with `nix-garden`;
      retain `hardy` only as the host name.
- [x] Keep nix-garden's existing `origin` as the canonical remote.
- [x] Commit post-merge naming and link cleanup separately from the merge.

## Verify and Cut Over

- [x] Run the complete nix-garden quality gate and inspect flake outputs.
- [x] Verify both histories and representative renamed files remain reachable.
- [x] Audit links, executable bits, ignored files, and instructions.
- [x] Clone the consolidated remote fresh and repeat checks.
- [x] On `hardy`, clone nix-garden beside the old nix-hardy checkout; do not
      mutate or delete the recovery checkout.
- [x] From the fresh nix-garden clone on `hardy`, run the gate and pre-flight,
      apply the same configuration, and verify the running generation.
- [x] Use Codex on `hardy` to make one small meaningful configuration change;
      preview, apply, verify, commit, and push it from nix-garden.
- [ ] Pull that commit on Galois and verify both machines agree.
- [x] Push nix-garden only after local validation.
- [ ] Archive `daneroo/nix-hardy` only after the pushed nix-garden clone is
      proven; do not delete either local source during this plan.

Hardy proof evidence, 2026-07-12:

- `~/nix-garden` and `~/nix-hardy` existed side by side on `hardy`; only
  `~/nix-garden` was used for the proof.
- `main` matched `origin/main` at `7fcd8eb7afe1a5a09f53ef142f8f2d3dd1fecb15`
  before the local package proof.
- `just pre-commit` and `just pre-flight` passed before the first switch.
- The first switch from `~/nix-garden` applied
  `/nix/store/whcfypv9k3wd3y2z4nzrfzby886qiw4j-nixos-system-hardy-26.05.20260707.0ad6f47`,
  matching the pre-flight build and proving the canonical checkout can drive
  Hardy.
- The small reversible configuration change added `btop` and `jq` to the managed
  system package set; `just pre-commit` and `just pre-flight` passed.
- The second switch applied
  `/nix/store/4rbapn7cabjawj3yyg4qrrq6bq0a0l9i-nixos-system-hardy-26.05.20260707.0ad6f47`.
  `/run/current-system` and `/nix/var/nix/profiles/system` both resolved to that
  path afterward.
- Verified `sshd` and `NetworkManager` enabled and active, NetworkManager
  connected, and `jq`, `btop`, `git`, `gh`, `just`, `bun`, `codex`, `curl`,
  `vim`, `ssh`, `nmcli`, and `nix` available from `/run/current-system/sw/bin`.
