set dotenv-load := false

flake := ".#hardy"

bootstrap:
    ./scripts/bootstrap-apply.sh

pre-commit:
    ./scripts/pre-commit.sh

check:
    nix flake check

preview:
    nixos-rebuild dry-build --flake {{flake}}

build:
    nixos-rebuild build --flake {{flake}}

apply: check preview build
    @printf 'Apply {{flake}} to this machine? [y/N] '; \
    read answer; \
    case "$answer" in \
      y|Y|yes|YES) sudo nixos-rebuild switch --flake {{flake}} ;; \
      *) echo 'apply aborted'; exit 1 ;; \
    esac
