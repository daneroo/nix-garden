# Bootstrap Flake

Status: planning

Goal: reach v0.1: a minimal reproducible NixOS config that can rebuild `hardy`, be pushed to GitHub, and make it easy to get files in and out of the machine.

- [x] Phase 0: already done
  - [x] Use `nix-hardy` as the clean NixOS repo.
  - [x] Keep `homelab-config-garden` as source material and history.
  - [x] Use 1Password GUI to retrieve credentials.
  - [x] Authenticate Codex.
  - [x] Capture repo layout convention in README and docs.
  - [x] Capture C436F throttling context in `docs/throttling.md`.
  - [x] Capture C436F performance measurements in `docs/performance.md`.

- [ ] Phase 1: first pushable and rebuildable repo
  - [x] Add the smallest NixOS host output for `hardy`.
  - [x] Put the bootstrap tools in system packages so a rebuild makes the box usable:
    - `git`
    - `ghostty`
    - `curl`
    - `vim`
    - `fresh-editor`
    - `_1password-gui`
    - `gh`
    - `codex`
    - `just`
  - [ ] Add a `Justfile` for check, preview, build, and apply.
  - [x] Preserve the current generated hardware config.
  - [x] Preserve the current NixOS state version.
  - [x] Generate `flake.lock`.
  - [x] Add `.gitignore` for local/editor/build outputs.
  - [x] Add one-time bootstrap path from default install to flake-managed baseline.
  - [x] Add a pre-commit-equivalent target for local checks.
  - [x] Add a self-documenting default `just` target.
  - [ ] Validate the flake:
    - [x] Run `nix flake check`.
    - [x] Build the system with `nixos-rebuild build --flake .#hardy`.
    - [x] Confirm build output has no unexpected warnings.
    - [x] Build a second time to confirm the config is stable/idempotent.
    - [x] Confirm the expected tools are present in the built system closure:
      - `git`
      - `ghostty`
      - `curl`
      - `vim`
      - `fresh`
      - `1password`
      - `gh`
      - `codex`
  - [x] Configure repo-local git identity.
  - [x] Rename initial branch to `main`.
  - [ ] Authenticate `gh`.
    - [x] Generate an SSH key for GitHub if one is not already present.
    - [x] Add the SSH public key to GitHub.
    - [ ] Verify SSH auth to GitHub.
  - [x] Create or connect the GitHub remote.
  - [x] Make the initial commit.
  - [x] Push the repo.

- [ ] Phase 2+: rebuild from remote
  - [ ] Document clone-and-rebuild, including direct URL patterns if useful.
