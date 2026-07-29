set dotenv-load := false

blessed_hosts := "hardy gauss"
hostname := `hostname`
flake := ".#" + hostname

# Show this helpful listing.
default:
    @just --list --unsorted

# Check pre-commit invariants: shell, formatting, Markdown, and flake.
check: _shell-check _fmt-check _lint-md _typecheck-e2e-bun _flake-check

# Format supported repository files.
fmt:
    bunx prettier --write .

# Show the running NixOS revision beside this repository's working state.
current-state:
    scripts/current-state.sh

# Check, build, and compare desired with running; never touches inputs (see `update`).
plan:
    just _host-check
    just _git-state
    just check
    just _build
    just _diff

# Update locked inputs, then plan.
update:
    @echo "== update: nix flake update =="
    nix flake update
    @echo "== update result: git diff -- flake.lock =="
    git diff -- flake.lock
    just plan

# Plan, confirm, switch, and verify.
[script('bash')]
apply:
    set -uo pipefail
    just plan || exit 1
    echo "== apply: sudo nixos-rebuild switch --flake {{ flake }} =="
    printf 'Apply {{ flake }} to this machine? [y/N] '
    read -r answer
    case "$answer" in
      y|Y|yes|YES) ;;
      *) echo 'apply aborted'; exit 1 ;;
    esac
    sudo nixos-rebuild switch --flake {{ flake }}
    switch_status=$?
    # switch-to-configuration exits non-zero when live user-session units fail
    # to restart. On a desktop that is routine and does not mean the switch was
    # rejected, so verify regardless rather than aborting here; the earlier
    # behavior skipped verification in exactly the case that most needed it.
    if [[ $switch_status -ne 0 ]]; then
      echo "== warning: nixos-rebuild exited ${switch_status}; verifying anyway =="
      echo "== on a live desktop this is usually GNOME user units; check below =="
    fi
    just _verify
    verify_status=$?
    if [[ $verify_status -ne 0 ]]; then
      echo 'verify failed: the running system does not match ./result' >&2
    fi
    if [[ $switch_status -ne 0 || $verify_status -ne 0 ]]; then
      exit 1
    fi

# Run desktop assertions headlessly, visibly, or open an exploratory VM.
[script('bash')]
e2e-vm *args:
    scripts/e2e-vm.sh {{ args }}

[private]
[script('bash')]
_host-check:
    set -euo pipefail
    if [[ ! " {{ blessed_hosts }} " == *" {{ hostname }} "* ]]; then
      echo "unrecognized hostname '{{ hostname }}'; blessed hosts: {{ blessed_hosts }}" >&2
      exit 1
    fi

[private]
[script('bash')]
_git-state:
    set -euo pipefail
    echo '== git: git status --short =='
    git rev-parse --is-inside-work-tree >/dev/null
    if [[ ! -e /run/current-system ]]; then
      echo 'plan requires NixOS with /run/current-system; run it on the target host' >&2
      exit 1
    fi
    status="$(git status --short)"
    if [[ -z "$status" ]]; then
      echo 'working tree clean'
      exit 0
    fi
    printf '%s\n' "$status"
    if grep -q '^??' <<<"$status"; then
      echo 'warning: Nix excludes untracked files from this Git flake'
    fi
    printf 'Continue with this working tree? [Y/n] '
    read -r answer
    case "$answer" in
      n|N|no|NO) echo 'plan aborted'; exit 1 ;;
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
[script('bash')]
_typecheck-e2e-bun:
    set -euo pipefail
    echo "== TypeScript: strict Bun E2E project =="
    (cd tests/e2e/bun && bun install --frozen-lockfile)
    typescript_store="$(nix build --no-link --print-out-paths .#nixosConfigurations.gauss.pkgs.typescript)"
    "$typescript_store/bin/tsc" --noEmit --project tests/e2e/bun/tsconfig.json

[private]
_flake-check:
    @echo "== flake: nix flake check =="
    nix flake check

[private]
_build:
    @echo "== build: nixos-rebuild build --flake {{ flake }} =="
    nixos-rebuild build --flake {{ flake }}

[private]
_diff:
    @echo "== diff: nix store diff-closures /run/current-system ./result =="
    nix store diff-closures /run/current-system ./result

[private]
_verify:
    @echo "== verify: running system matches ./result =="
    test "$(readlink -f /run/current-system)" = "$(readlink -f ./result)"
    sudo -n true
