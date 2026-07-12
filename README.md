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
just pre-flight
just apply
```

`just apply` runs pre-flight, asks, then switches.

## Documentation

See [AGENTS.md](AGENTS.md) for working instructions and [docs/](docs/) for
reference — bootstrap, workflow, workspace, and hardware notes.
