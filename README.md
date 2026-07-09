# nix-hardy

Reproducible NixOS setup for `hardy`, an ASUS Chromebook Flip C436F / Google Helios with MrChromebox firmware.

v0.1 goal: rebuild `hardy` from a flake, push the repo, and make iteration from another machine practical.

Proof target: wipe, clone this repo, run `just bootstrap`, and return to this baseline.

Initial bootstrap shell:

```sh
export NIXPKGS_ALLOW_UNFREE=1
nix-shell -p git ghostty curl vim fresh-editor _1password-gui gh codex just --arg config '{ allowUnfree = true; }'
```

See `docs/bootstrap.md` for the fresh-start path.

## Operations

First apply:

```sh
just bootstrap
```

Normal loop:

```sh
just check
just preview
just build
```

Apply the config:

```sh
just apply
```

`just apply` runs check, preview, and build first, then asks before switching.

## Layout

```text
docs/
  bootstrap.md
  file-layout.md
  performance.md
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
