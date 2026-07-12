set default-list := true
set dotenv-load := false

flake := ".#hardy"

# Verify the repository.
check: _shell-check _fmt-check _lint-md _flake-check

# Format supported repository files.
fmt:
    bunx prettier --write .

# Verify, build, confirm, and switch hardy.
apply: _pre-flight
    @echo "== apply: sudo nixos-rebuild switch --flake {{flake}} =="
    @printf 'Apply {{flake}} to this machine? [y/N] '; \
    read answer; \
    case "$answer" in \
      y|Y|yes|YES) sudo nixos-rebuild switch --flake {{flake}} ;; \
      *) echo 'apply aborted'; exit 1 ;; \
    esac

[private]
_shell-check:
    @echo "== shell syntax: bash -n scripts/*.sh =="
    bash -n scripts/*.sh

[private]
_fmt-check:
    @echo "== formatting: bunx prettier --check . =="
    bunx prettier --check .

[private]
_lint-md:
    @echo "== markdown: bunx markdownlint-cli2 =="
    # The shorter Prosodio glob missed nested thoughts files here; keep explicit depths.
    bunx markdownlint-cli2 "*.md" "**/*.md" "**/**/*.md" "**/**/**/*.md"

[private]
_flake-check:
    @echo "== flake: nix flake check =="
    nix flake check

[private]
_pre-flight: check _preview _build

[private]
_preview:
    @echo "== preview: nixos-rebuild dry-build --flake {{flake}} =="
    nixos-rebuild dry-build --flake {{flake}}

[private]
_build:
    @echo "== build: nixos-rebuild build --flake {{flake}} =="
    nixos-rebuild build --flake {{flake}}

[private]
bootstrap:
    ./scripts/bootstrap-apply.sh
