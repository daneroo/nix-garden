# Repository command surface

Status: planned

Goal: make updates to `hardy` a clear `plan` then `apply` reconciliation loop.

- [ ] Implement the documented public Just surface and private helpers without
      adding scripts. `[tier: med]`
- [ ] Make `plan` precheck Git and flake state, optionally update inputs,
      verify, build, and compare with the running system. `[tier: med]`
- [ ] First build a passwordless-sudo-only generation; run `sudo -v` immediately
      before switching to it and verify `sudo -n true`. `[tier: high]`
- [ ] Move `hardy` to locked `nixos-unstable`; make `apply` replan without
      updates, confirm, switch, and verify. `[tier: high]`
- [ ] Exercise both plan paths, apply with Daniel's authorization, document the
      recovery path, and run `just pre-commit`. `[tier: high]`
