# Herdr workflow

Status: done

Goal: install and verify the upstream Herdr v0.7.5 workflow on `hardy`.

Acceptance:

- [x] `flake.nix` pins `github:ogulcancelik/herdr/v0.7.5` without overriding
      Herdr's internal inputs or advancing the existing `nixpkgs` lock.
- [x] The planned closure adds `herdr.packages.${system}.default` and no
      unexpected host-policy changes; inspect before activation. `[tier: high]`
- [x] After Daniel authorizes activation, `herdr --version` reports v0.7.5,
      `/run/current-system` matches `./result`, and `sshd` and NetworkManager
      remain enabled and active. `[tier: high]`
- [x] A Herdr session launches, detaches, reattaches, and exposes native Codex
      and Hermes agent detection without persistent configuration.
      `[tier: high]`

- [x] Add the upstream Herdr flake input and system package. `[tier: med]`
- [x] Update the Herdr input from v0.7.3 to v0.7.5 without changing the root
      `nixpkgs` lock. `[tier: med]`
- [x] Check and plan the v0.7.5 update; the closure changes only
      `herdr 0.7.3 -> 0.7.5` (+2.4 MiB). `[tier: high]`
- [x] Run `just check` and `just plan`; inspect the lock and closure.
      `[tier: high]`
- [x] Apply only after Daniel confirms the reviewed generation. `[tier: high]`
- [x] Apply the reviewed v0.7.5 generation after Daniel confirms it, then verify
      the system package and host health. `[tier: high]`
- [x] Verify the baseline Herdr and Codex workflow, then run `just check`.
      `[tier: high]`
- [x] Commit and push the execution branch. `[tier: med]`

Activation evidence, 2026-07-12:

- [x] `/run/current-system` and `./result` resolved to
      `/nix/store/c08lq0ksivk9yaicb0ggf81jfmdr8y8c-nixos-system-hardy-26.11.20260711.e7a3ca8`.
- [x] `/run/current-system/sw/bin/herdr --version` reported `herdr 0.7.3`.
- [x] The installed system binary runs the live `remote-client-bridge`; the
      existing `~/.local/bin/herdr server` remains untouched and protocol
      compatible.
- [x] `sudo -n true` passed; `sshd` and NetworkManager remained enabled and
      active, with NetworkManager connected.
- [x] Confirm that the explicit Codex integration hook is not installed and
      defer it pending declarative configuration ownership.
- [x] Verify session detach and reattach remotely from Galois without disrupting
      the active workflow.

Activation evidence, 2026-07-22:

- [x] `/run/current-system` and `./result` resolved to
      `/nix/store/gimz66b53vrcx9lfgri7v3yq3qnmd6pd-nixos-system-hardy-26.11.20260719.241313f`.
- [x] `/run/current-system/sw/bin/herdr --version` reported `herdr 0.7.5`.
- [x] `sshd` and NetworkManager remained enabled and active; the system was
      running with zero failed units.
- [x] Daniel detached and reattached a live session remotely from Galois; it
      remained usable through the v0.7.3-to-v0.7.5 Herdr protocol upgrade.
- [x] The live session reports Codex and Hermes panes through native agent
      detection. The explicit Codex hook is intentionally deferred until its
      configuration can be owned declaratively.
