# nix-hardy

Reproducible NixOS setup for `hardy`, an ASUS Chromebook Flip C436F / Google Helios with MrChromebox firmware.

v0.1 goal: rebuild `hardy` from a flake, push the repo, and make iteration from another machine practical.

Initial bootstrap command:

```sh
export NIXPKGS_ALLOW_UNFREE=1
nix-shell -p git ghostty curl vim fresh-editor _1password-gui gh codex --arg config '{ allowUnfree = true; }'
```

See `docs/bootstrap.md` for the fresh-start path.

## Layout

```text
docs/
  bootstrap.md
  file-layout.md
  throttling.md

thoughts/
  BACKLOG.md
  plans/
    feature.md
    archive/
      done-feature-to-preserve.md
  design/
    concept-to-keep.md
```

- `docs/`: stable explanations, runbooks, and machine facts.
- `thoughts/BACKLOG.md`: items that are not yet planned.
- `thoughts/plans/`: active plans with status, goal, and nested checkbox bullets.
- `thoughts/plans/archive/`: completed plans worth preserving.
- `thoughts/design/`: pre-planning concepts that may later become active plans.
