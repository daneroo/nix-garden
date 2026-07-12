set dotenv-load := false

flake := ".#hardy"

default:
    @echo "Targets:"
    @echo "  just bootstrap   one-time first apply from a default install"
    @echo "  just pre-flight  check, preview, and build without switching"
    @echo "  just apply       run pre-flight, ask, then switch"
    @echo "  just check       run nix flake check"
    @echo "  just preview     show what would be built/downloaded"
    @echo "  just build       build without switching"
    @echo "  just fmt         format supported repository files"
    @echo "  just fmt-check   verify formatting without writing"
    @echo "  just lint-md     lint Markdown structure"
    @echo "  just pre-commit  local checks before commit"

bootstrap:
    ./scripts/bootstrap-apply.sh

pre-commit:
    ./scripts/pre-commit.sh

fmt:
    bunx prettier --write .

fmt-check:
    bunx prettier --check .

lint-md:
    # The shorter Prosodio glob missed nested thoughts files here; keep explicit depths.
    bunx markdownlint-cli2 "*.md" "**/*.md" "**/**/*.md" "**/**/**/*.md"

check:
    @echo "== check: nix flake check =="
    nix flake check

preview:
    @echo "== preview: nixos-rebuild dry-build =="
    nixos-rebuild dry-build --flake {{flake}}

build:
    @echo "== build: nixos-rebuild build =="
    nixos-rebuild build --flake {{flake}}

pre-flight: check preview build

apply: pre-flight
    @echo "== apply: nixos-rebuild switch =="
    @printf 'Apply {{flake}} to this machine? [y/N] '; \
    read answer; \
    case "$answer" in \
      y|Y|yes|YES) sudo nixos-rebuild switch --flake {{flake}} ;; \
      *) echo 'apply aborted'; exit 1 ;; \
    esac
