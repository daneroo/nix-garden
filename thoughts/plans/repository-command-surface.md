# Repository command surface

Status: planned

Goal: make updates to `hardy` a clear `plan` then `apply` reconciliation loop.

Acceptance:

- `just plan` works with the locked inputs and reports only the intended
  passwordless-sudo closure change before the first activation.
- After the passwordless-sudo activation, `/run/current-system` matches the
  planned result, `sudo -n true` succeeds, and `sshd` and `NetworkManager`
  remain enabled and active.
- The later `nixos-unstable` plan reports the expected channel/package movement,
  including a changed `codex --version`; unexpected service, boot, user, or
  network policy changes stop the migration.
- `just apply` replans without updating inputs, asks for explicit activation
  confirmation, switches to the planned result, and verifies the active system.
- `just check` passes before any commit, and the recovery path documents how to
  boot or switch back to the previous generation.

- [ ] Implement the documented public Just surface and private helpers without
      adding scripts. `[tier: med]`
- [ ] Make `plan` precheck Git and flake state, optionally update inputs, call
      `just check` to fail fast, then build and compare with running.
      `[tier: med]`
- [ ] First build a passwordless-sudo-only generation; run `sudo -v` immediately
      before switching to it and verify `sudo -n true`. `[tier: high]`
- [ ] Move `hardy` to locked `nixos-unstable`; make `apply` replan without
      updates, confirm, switch, and verify. `[tier: high]`
- [ ] Exercise both plan paths, apply with Daniel's authorization, document the
      recovery path, and run `just check`. `[tier: high]`
