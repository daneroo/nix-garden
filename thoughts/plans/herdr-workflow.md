# Herdr workflow

Status: active

Goal: install and verify the upstream Herdr v0.7.3 workflow on `hardy`.

Acceptance:

- [ ] `flake.nix` pins `github:ogulcancelik/herdr/v0.7.3` without overriding
      Herdr's internal inputs or advancing the existing `nixpkgs` lock.
- [ ] The planned closure adds `herdr.packages.${system}.default` and no
      unexpected host-policy changes; inspect before activation. `[tier: high]`
- [ ] After Daniel authorizes activation, `herdr --version` reports v0.7.3,
      `/run/current-system` matches `./result`, and `sshd` and NetworkManager
      remain enabled and active. `[tier: high]`
- [ ] A Herdr session launches, detaches, reattaches, and exposes the Codex
      integration without requiring persistent configuration. `[tier: high]`

- [ ] Add the upstream Herdr flake input and system package. `[tier: med]`
- [ ] Run `just check` and `just plan`; inspect the lock and closure.
      `[tier: high]`
- [ ] Apply only after Daniel confirms the reviewed generation. `[tier: high]`
- [ ] Verify the baseline Herdr and Codex workflow, then run `just check`.
      `[tier: high]`
- [ ] Commit and push the execution branch. `[tier: med]`
