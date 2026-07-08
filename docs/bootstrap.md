# Bootstrap

Goal: make a fresh `hardy` install reproducible from this repo with as little hand work as possible.

## Current Manual Bootstrap

This is the command that started the repo:

```sh
export NIXPKGS_ALLOW_UNFREE=1
nix-shell -p git ghostty curl vim fresh-editor _1password-gui gh codex --arg config '{ allowUnfree = true; }'
```

Manual steps completed on this install:

- [x] Opened 1Password GUI.
- [x] Used 1Password GUI to retrieve credentials.
- [x] Authenticated Codex.
- [ ] Create a flake NixOS config that installs the bootstrap tools as system packages.
- [ ] Push the repo to GitHub.
- [ ] Document the clone-and-rebuild path.

## v0.1 Target

After v0.1, a fresh install should be able to reach this workflow:

```sh
git clone <repo-url> nix-hardy
cd nix-hardy
sudo nixos-rebuild switch --flake .#hardy
```

## Phases

- Phase 0: manual bootstrap already completed.
- Phase 1: first pushable repo that can minimally rebuild `hardy` with the bootstrap tools installed as system packages.
- Phase 2+: rebuild from the remote repo, possibly directly from a URL pattern.

The later target is a single command that can rebuild the machine from the repo after clone.
