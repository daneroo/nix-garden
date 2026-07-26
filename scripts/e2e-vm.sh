#!/usr/bin/env bash
set -euo pipefail

readonly blessed_hosts="hardy gauss"
test_artifact_root=""

main() {
  local mode="test"
  local show=false
  local host
  local host_was_set=false
  host="$(hostname)"

  while (($#)); do
    case "$1" in
      --show)
        show=true
        ;;
      --no-test)
        mode="explore"
        show=true
        ;;
      --host)
        shift
        if (($# == 0)); then
          fail "--host requires a hostname"
        fi
        host="$1"
        host_was_set=true
        ;;
      --host=*)
        host="${1#--host=}"
        host_was_set=true
        ;;
      -h | --help)
        usage
        return
        ;;
      *)
        fail "unrecognized argument: $1"
        ;;
    esac
    shift
  done

  if [[ "$mode" == "test" && "$host_was_set" == true ]]; then
    fail "--host is valid only with --no-test"
  fi

  if [[ "$mode" == "explore" ]]; then
    run_exploration "$host"
  else
    run_tests "$show"
  fi
}

usage() {
  cat <<'EOF'
Usage:
  just e2e-vm [--show]
  just e2e-vm --no-test [--host HOST]

Modes:
  (default)  Run all desktop assertions headlessly in a fresh VM.
  --show     Run the same assertions in a visible fresh VM.
  --no-test  Open a visible persistent VM without running assertions.
EOF
}

fail() {
  echo "e2e-vm: $*" >&2
  echo "run 'just e2e-vm --help' for usage" >&2
  exit 2
}

cleanup_test_artifacts() {
  if [[ -n "$test_artifact_root" && -d "$test_artifact_root" ]]; then
    rm -rf -- "$test_artifact_root"
  fi
}

require_display() {
  local runtime_dir
  local socket

  runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  export XDG_RUNTIME_DIR="$runtime_dir"

  if [[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]]; then
    return
  fi

  for socket in "$runtime_dir"/wayland-[0-9]*; do
    if [[ -S "$socket" ]]; then
      export WAYLAND_DISPLAY="${socket##*/}"
      return
    fi
  done

  fail "no graphical session found under $runtime_dir"
}

run_tests() {
  local show="$1"
  local out
  local driver
  local started_ns
  local finished_ns
  local status

  test_artifact_root="$(mktemp -d)"
  trap cleanup_test_artifacts EXIT
  out="$test_artifact_root/test-desktop"
  mkdir -p "$out"

  if [[ "$show" == true ]]; then
    require_display
    echo "== show: test-desktop =="
    driver="$(
      nix build .#test-desktop.driverInteractive --no-link --print-out-paths
    )"
  else
    echo "== running: test-desktop =="
    driver="$(nix build .#test-desktop.driver --no-link --print-out-paths)"
  fi

  started_ns="$(date +%s%N)"
  set +e
  if [[ "$show" == true ]]; then
    # driverInteractive bakes in --interactive. Select the normal entry point
    # while retaining its graphical VM configuration.
    NIX_GARDEN_TEST_SHOW=1 \
      "$driver/bin/nixos-test-driver" \
      --no-interactive \
      --log-level warning \
      -o "$out" \
      --junit-xml junit.xml \
      >/dev/null
  else
    "$driver/bin/nixos-test-driver" \
      --log-level warning \
      -o "$out" \
      --junit-xml junit.xml \
      >/dev/null
  fi
  status=$?
  set -e

  printf '%s\n' "$status" >"$out/status"
  finished_ns="$(date +%s%N)"
  printf '%s\n' "$((finished_ns - started_ns))" >"$out/wall-nanoseconds"
  echo
  nix run .#test-report -- "$test_artifact_root"
}

run_exploration() {
  local host="$1"
  local image_dir

  if [[ " $blessed_hosts " != *" $host "* ]]; then
    fail "unrecognized host '$host'; blessed hosts: $blessed_hosts"
  fi

  require_display
  echo "== vm: nix build .#nixosConfigurations.$host.config.system.build.vm =="
  # Not nixos-rebuild build-vm: it hardcodes ./result, which would collide with
  # the real system closure left by plan and apply.
  nix build ".#nixosConfigurations.$host.config.system.build.vm" \
    --out-link "result-$host"

  # The persistent image stays outside the working tree so it cannot affect
  # what Git flakes include.
  image_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/nix-garden/vm"
  mkdir -p "$image_dir"
  export NIX_DISK_IMAGE="$image_dir/$host.qcow2"
  echo "== vm: persistent disk $NIX_DISK_IMAGE =="

  # VM mode ignores hardware-configuration.nix filesystems. It validates
  # services, packages, users, and sessions, never boot or disk layout.
  exec "./result-$host/bin/run-$host-vm"
}

main "$@"
