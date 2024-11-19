# Clan garden

- <https://docs.clan.lol/getting-started/>

```bash
# on galois
nix shell git+https://git.clan.lol/clan/clan-core#clan-cli

clan --help
clan flakes create pxmx-clan
```

## Installer

Can I write an iso file?

```bash
# on minimal-amd64 (or any working x86_64 nixos...)
nix shell git+https://git.clan.lol/clan/clan-core#clan-cli

scp -p galois.imetrical.com:.ssh/id_ed25519.pub galois_id_ed25519.pub

clan flash write --flake git+https://git.clan.lol/clan/clan-core \
  --ssh-pubkey galois_id_ed25519.pub \
  --keymap us \
  --language en_US.UTF-8 \
  --disk main clan-installer.iso \
  flash-installer
```

