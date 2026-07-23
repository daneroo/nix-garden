set dotenv-load := false

blessed_hosts := "hardy gauss"
hostname := `hostname`
flake := ".#" + hostname

default:
    @just --list

# Check, build, and compare desired with running; optionally update inputs.
plan:
    just _host-check
    just _git-state
    just _maybe-update
    just check
    just _build
    just _diff

# Replan without updates, confirm, switch, and verify.
apply:
    just pre-flight
    @echo "== apply: sudo nixos-rebuild switch --flake {{ flake }} =="
    @printf 'Apply {{ flake }} to this machine? [y/N] '; \
    read answer; \
    case "$answer" in \
      y|Y|yes|YES) sudo nixos-rebuild switch --flake {{ flake }} ;; \
      *) echo 'apply aborted'; exit 1 ;; \
    esac
    just _verify

# Check pre-commit invariants: shell, formatting, Markdown, and flake.
check: _shell-check _fmt-check _lint-md _flake-check

# Check, build, and diff without updating inputs or switching; the gate agents and CI can run.
pre-flight:
    just _host-check
    just _git-state
    just check
    just _build
    just _diff

# Format supported repository files.
fmt:
    bunx prettier --write .

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
[script('bash')]
_maybe-update:
    set -euo pipefail
    printf 'Update locked inputs before planning? [y/N] '
    read -r answer
    case "$answer" in
      y|Y|yes|YES)
        echo '== update: nix flake update =='
        nix flake update
        echo '== update result: git diff -- flake.lock =='
        git diff -- flake.lock
        ;;
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
