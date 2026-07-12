# Repository command surface

Status: active

Goal: make updates to `hardy` a clear `plan` then `apply` reconciliation loop.

Acceptance:

- [x] `just plan` works with the locked inputs and reports only the intended
      passwordless-sudo closure change before the first activation.
- [x] After the passwordless-sudo activation, `/run/current-system` matches the
      planned result, `sudo -n true` succeeds, and `sshd` and `NetworkManager`
      remain enabled and active.
- [ ] The later `nixos-unstable` plan reports the expected channel/package
      movement, including a changed `codex --version`; unexpected service, boot,
      user, or network policy changes stop the migration.
- [x] `just apply` replans without updating inputs, asks for explicit activation
      confirmation, and switches to the planned result.
- [x] The fixed `_verify` helper verifies that the active system matches the
      planned result and `sudo -n true` succeeds.
- [ ] `just check` passes before any commit, and the recovery path documents how
      to boot or switch back to the previous generation.

- [x] Implement the documented public Just surface and private helpers without
      adding scripts. `[tier: med]`
- [x] Make `plan` precheck Git and flake state, optionally update inputs, call
      `just check` to fail fast, then build and compare with running.
      `[tier: med]`
- [x] First build a passwordless-sudo-only generation; run `sudo -v` immediately
      before switching to it and verify `sudo -n true`. `[tier: high]`
- [ ] Move `hardy` to locked `nixos-unstable`; make `apply` replan without
      updates, confirm, switch, and verify. `[tier: high]`
- [ ] Exercise both plan paths, apply with Daniel's authorization, document the
      recovery path, and run `just check`. `[tier: high]`

Passwordless-sudo proof, 2026-07-12:

- [x] Confirmed a clean worktree and fast-forward state before planning.
- [x] Ran `just plan` with locked inputs and declined input updates.
- [x] Inspected the plan build result:
      `/nix/store/n6fzdys7s9mv8mj3fg37j4hbm9ifkdrp-nixos-system-hardy-26.05.20260707.0ad6f47`.
- [x] Verified the closure diff was empty.
- [x] Verified the generated sudoers diff only changed `%wheel` from passworded
      `SETENV` to `NOPASSWD:SETENV`.
- [x] Asked Daniel to run `sudo -v` immediately before activation.
- [x] Ran `just apply`; it replanned with locked inputs and asked for activation
      confirmation.
- [x] Daniel authorized activation, and Hardy switched to the planned result.
- [x] Verified `/run/current-system` and `./result` resolved to the planned
      path.
- [x] Verified `sudo -n true` succeeded.
- [x] Verified `sshd` remained enabled and active.
- [x] Verified `NetworkManager` remained enabled and active.
- [x] Identified that the first `just apply` verification failure was an
      escaping bug in `_verify`, not an activation failure.
- [x] Fixed `_verify` to use shell command substitutions correctly.
- [x] Ran the fixed `_verify` helper successfully.
