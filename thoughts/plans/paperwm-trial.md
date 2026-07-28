# PaperWM Trial

Status: done

Goal: make PaperWM usable and switchable on both desktop hosts.

- [x] Record the clean `gauss` baseline and current NixOS generation.
- [x] On `paperwm-trial`, install and enable PaperWM for `gauss` only; keep its
      defaults and leave `hardy` and the E2E harness unchanged. `[tier: low]`
- [x] Run `just check`, commit, and push the branch.
- [x] On clean `gauss`, switch to the branch, run `just plan`, review the
      meaningful system diff, and apply it.
- [x] Confirm PaperWM is active and basic window management works in the real
      GNOME session.
- [x] Expose the toggle through Vicinae from the system profile and remove the
      temporary user-owned link from `gauss`. `[tier: low]`
- [x] Share PaperWM across `hardy` and `gauss`, float Vicinae by default, and
      validate tiling and toggle behavior after logout/login.
- [x] Harvest the accepted behavior into `docs/tiling-windows.md`; leave E2E VM
      assessment to Daniel as separate post-merge work.

Recovery: apply clean `main`, or select the previous NixOS generation if the
desktop cannot be used normally.
