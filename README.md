# nix-garden

Reproducible configuration and operational control plane for Daniel's homelab.
The first managed host is `hardy`, an ASUS Chromebook Flip C436F / Google Helios
with MrChromebox firmware.

v0.1 goal: rebuild `hardy` from a flake, push the repo, and make iteration from
another machine practical.

Proof target: wipe, clone this repo, run the bootstrap script, and return to
this baseline.

Initial bootstrap shell:

```sh
nix-shell -p git
git clone https://github.com/daneroo/nix-garden.git
cd nix-garden
./scripts/bootstrap-apply.sh
```

See `docs/bootstrap.md` for the fresh-start path.

## Operations

First apply:

```sh
./scripts/bootstrap-apply.sh
```

Normal loop:

```sh
just
just check
just plan
just apply
```

Bare `just` lists the public commands. `plan` checks, builds, and compares
desired with running, without touching locked inputs (`just update` does that
separately). `apply` runs `plan`, asks, switches, and verifies.

The bootstrap script is a one-time bridge. It assumes only Nix and Git and
defensively enables the Nix features the normal system already provides.

## Documentation

See [AGENTS.md](AGENTS.md) for working instructions and [docs/](docs/) for
reference — bootstrap, workflow, workspace, and hardware notes.
