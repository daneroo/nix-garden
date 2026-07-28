# PaperWM Trial

Status: active

Goal: make PaperWM usable on `gauss` for an immediate real-hardware trial.

- [x] Record the clean `gauss` baseline and current NixOS generation.
- [x] On `paperwm-trial`, install and enable PaperWM for `gauss` only; keep its
      defaults and leave `hardy` and the E2E harness unchanged. `[tier: low]`
- [x] Run `just check`, commit, and push the branch.
- [x] On clean `gauss`, switch to the branch, run `just plan`, review the
      meaningful system diff, and apply it.
- [x] Confirm PaperWM is active and basic window management works in the real
      GNOME session.
- [ ] Expose the toggle through Vicinae from the system profile and remove the
      temporary user-owned link from `gauss`. `[tier: low]`
- [ ] Stop with PaperWM usable and switchable. Daniel's experience will decide
      the production keybindings and E2E impact later.

Recovery: apply clean `main`, or select the previous NixOS generation if the
desktop cannot be used normally.
