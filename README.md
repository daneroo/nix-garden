# nix-garden

Reproducible configuration and operational control plane for Daniel's homelab.
The first managed host is `hardy`, an ASUS Chromebook Flip C436F / Google Helios
with MrChromebox firmware.

v0.1 goal: rebuild `hardy` from a flake, push the repo, and make iteration from
another machine practical.

Proof target: wipe, clone this repo, run `just bootstrap`, and return to this
baseline.

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
just
just check
just plan
just apply
```

Bare `just` lists the public commands. `plan` optionally updates inputs, checks,
builds, and compares desired with running. `apply` replans without updates,
asks, switches, and verifies.

`bootstrap` is a special one-time bridge. It requires `just` from the initial
bootstrap shell and defensively enables the Nix features the normal system
already provides.

## Documentation

See [AGENTS.md](AGENTS.md) for working instructions and [docs/](docs/) for
reference — bootstrap, workflow, workspace, and hardware notes.
