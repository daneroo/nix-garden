# Herdr workflow

Status: active

Goal: install and verify the upstream Herdr v0.7.3 workflow on `hardy`.

Acceptance:

- [x] `flake.nix` pins `github:ogulcancelik/herdr/v0.7.3` without overriding
      Herdr's internal inputs or advancing the existing `nixpkgs` lock.
- [x] The planned closure adds `herdr.packages.${system}.default` and no
      unexpected host-policy changes; inspect before activation. `[tier: high]`
- [x] After Daniel authorizes activation, `herdr --version` reports v0.7.3,
      `/run/current-system` matches `./result`, and `sshd` and NetworkManager
      remain enabled and active. `[tier: high]`
- [ ] A Herdr session launches, detaches, reattaches, and exposes the Codex
      integration without requiring persistent configuration. `[tier: high]`

- [x] Add the upstream Herdr flake input and system package. `[tier: med]`
- [x] Run `just check` and `just plan`; inspect the lock and closure.
      `[tier: high]`
- [x] Apply only after Daniel confirms the reviewed generation. `[tier: high]`
- [ ] Verify the baseline Herdr and Codex workflow, then run `just check`.
      `[tier: high]`
- [ ] Commit and push the execution branch. `[tier: med]`

Activation evidence, 2026-07-12:

- [x] `/run/current-system` and `./result` resolved to
      `/nix/store/c08lq0ksivk9yaicb0ggf81jfmdr8y8c-nixos-system-hardy-26.11.20260711.e7a3ca8`.
- [x] `/run/current-system/sw/bin/herdr --version` reported `herdr 0.7.3`.
- [x] The installed system binary runs the live `remote-client-bridge`; the
      existing `~/.local/bin/herdr server` remains untouched and protocol
      compatible.
- [x] `sudo -n true` passed; `sshd` and NetworkManager remained enabled and
      active, with NetworkManager connected.
- [ ] Install and verify the Codex integration hook.
- [ ] Create, detach, and reattach an isolated proof session without disturbing
      the live default session.
