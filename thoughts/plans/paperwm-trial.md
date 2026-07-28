# PaperWM Trial

Status: planned

Goal: make PaperWM usable on `gauss` for an immediate real-hardware trial.

- [ ] Record the clean `gauss` baseline and current NixOS generation.
- [ ] On `paperwm-trial`, install and enable PaperWM for `gauss` only; keep its
      defaults and leave `hardy` and the E2E harness unchanged. `[tier: low]`
- [ ] Run `just check`, commit, and push the branch.
- [ ] On clean `gauss`, switch to the branch, run `just plan`, review the
      meaningful system diff, and apply it.
- [ ] Confirm PaperWM is active and basic window management works in the real
      GNOME session.
- [ ] Stop with PaperWM usable. Daniel's experience will decide whether later
      work abandons or productionizes it.

Recovery: apply clean `main`, or select the previous NixOS generation if the
desktop cannot be used normally.
