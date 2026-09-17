#!/usr/bin/env bash
# Operate the Omarchy guest VM: prepare its files, install it, run it, and stop
# it. Plain QEMU in a GTK window -- no libvirt and no SPICE, so input reaches
# the guest through one translation hop instead of a remote-desktop protocol.
#
# This tool is opt-in. It never changes the NixOS configuration, and it takes
# QEMU and OVMF from the repository's locked nixpkgs input rather than
# installing anything onto the host.
set -euo pipefail

# Each release has one immutable identity. The download URL is versioned and
# moves, so the hash is what actually identifies an image: a release becomes
# usable here only once its published hash has been recorded below.
readonly known_releases=(4.0.1 4.0.2 4.0.3 4.0.4)
readonly newest_release="4.0.4"
release=""

iso_version=""
iso_url=""
iso_sha256=""
iso_bytes=""

select_release() {
  case "$release" in
    4.0.1)
      iso_sha256="69cbb4e10d98ad831c3c9f245b5757a9d1fedfd0c9592780e977d6f950dea8c3"
      iso_bytes="6227752960"
      ;;
    4.0.2)
      iso_sha256="2ef8e624aa1bec7e277e28056b8535a6c9373ba48d7ede3f1a01cb6d2373cfb8"
      iso_bytes="6227752960"
      ;;
    4.0.3)
      iso_sha256="03d60bc74306dca51f96e1a84b690871d8d606826b260edd0208962da8507d14"
      iso_bytes="6260654080"
      ;;
    4.0.4)
      iso_sha256="ddeded2758c48318d201dfdac905ecb28f570441883f0c052ea3cd5d05acf92d"
      iso_bytes="6185304064"
      ;;
    *)
      # A release newer than this script. Fetching its published hash is no
      # weaker than the recorded ones, which were obtained the same way -- the
      # hash still has to match after download, and the ISO comes from that
      # same host regardless. Recording it in the table above additionally
      # pins it to something reviewed in Git.
      discover_release
      ;;
  esac

  iso_version="Omarchy $release"
  iso_url="https://iso.omarchy.org/omarchy-$release.iso"
  readonly iso_version iso_url iso_sha256 iso_bytes
}

discover_release() {
  local url="https://iso.omarchy.org/omarchy-$release.iso"

  [[ "$release" =~ ^[0-9]+(\.[0-9]+)*$ ]] ||
    fail "'$release' is not a release number; known: ${known_releases[*]}"

  echo "== release $release is not recorded in this script; asking upstream ==" >&2
  iso_sha256="$(curl -fsS --max-time 30 "$url.sha256" | cut -d' ' -f1)" ||
    fail "no published hash for release $release at $url.sha256
Known releases: ${known_releases[*]}"
  [[ "$iso_sha256" =~ ^[0-9a-f]{64}$ ]] ||
    fail "upstream returned something that is not a sha256 for release $release"

  iso_bytes="$(curl -fsSI --max-time 30 "$url" |
    awk -F': ' 'tolower($1)=="content-length"{gsub(/\r/,"",$2); print $2}')"
  [[ "$iso_bytes" =~ ^[0-9]+$ ]] || fail "could not determine the size of $url"

  echo "== $release: sha256 $iso_sha256, $iso_bytes bytes ==" >&2
  echo "== record it in select_release() to pin it in Git ==" >&2
}

# keyd holds an exclusive grab on the physical keyboard and republishes it as
# this virtual device. Capturing the virtual one keeps keyd's remappings inside
# the guest; capturing the physical one is impossible and must never be
# attempted as a fallback.
readonly keyd_device_name="keyd virtual keyboard"

vm_root=""
iso_path=""
disk_path=""
pid_file=""
monitor_socket=""
inhibit_pid=""
qemu_command=()
qemu_pid=""

main() {
  local command="${1:-}"
  local raw_keyboard=1
  local want_gl=-1
  local foreground=0
  local requested=""

  case "$command" in
    -h | --help | "")
      usage
      return 0
      ;;
  esac
  shift

  while (($#)); do
    case "$1" in
      --no-raw-keyboard)
        raw_keyboard=0
        ;;
      --no-gl)
        want_gl=0
        ;;
      --foreground)
        foreground=1
        ;;
      -h | --help)
        usage
        return 0
        ;;
      -*)
        fail "unrecognized option: $1"
        ;;
      *)
        [[ -z "$requested" ]] || fail "release given twice: '$requested' and '$1'"
        requested="$1"
        ;;
    esac
    shift
  done

  resolve_release "$requested"
  resolve_paths

  case "$command" in
    prepare) cmd_prepare ;;
    install) cmd_install "$want_gl" "$foreground" ;;
    run) cmd_run "$raw_keyboard" "$want_gl" "$foreground" ;;
    status) cmd_status ;;
    stop) cmd_stop ;;
    force-stop) cmd_force_stop ;;
    *) fail "unrecognized command: $command" ;;
  esac
}

# There is one Omarchy VM. The release only decides which ISO to fetch and
# verify, never where the machine lives, so nothing multiplies per version.
resolve_release() {
  local requested="${1:-}"

  release="${requested:-$newest_release}"
}

usage() {
  cat <<'EOF'
Usage:
  just omarchy-vm install      Download, verify, and install the newest release.
  just omarchy-vm run          Boot the installed VM, accelerated, keyboard
                               captured. Toggle capture with both Ctrl keys.
  just omarchy-vm stop         Ask the guest to shut down cleanly.
  just omarchy-vm status       Report PID, running state, and paths in use.
  just omarchy-vm force-stop   Kill this VM's QEMU. Explicit last resort.
  just omarchy-vm prepare      Fetch and verify files without booting anything.

No arguments needed. There is one VM, at ~/vms/omarchy, and install takes the
newest known release (4.0.4). Name a release to pick another, for example
'just omarchy-vm install 4.0.1'. Installing over a system already on the disk
asks for confirmation first.

Options:
  -h, --help          Show this text.
  --no-raw-keyboard   Do not capture the keyboard. Host bindings will steal
                      keys from the guest; useful when something is wrong.
  --no-gl             Software rendering instead of virgl. Slower, but it
                      rules the GPU out when a guest will not display.
  --foreground        Block until the guest exits, with QEMU output on the
                      terminal. The default detaches and frees the prompt.

Tuning, all optional:
  OMARCHY_VM_ROOT           where the VM lives        (~/vms/omarchy)
  OMARCHY_SMP               guest cores               (4; 6 suits hardy)
  OMARCHY_MEMORY            guest memory in MiB       (8192)
  OMARCHY_DISK_SIZE         only when creating a disk (120G)
  OMARCHY_ALLOW_REINSTALL   1 skips the overwrite prompt when not interactive

Keyboard capture toggles with both Ctrl keys at once. While captured this host
has no keyboard, and QEMU's own Ctrl+Alt shortcuts will not work until you
release it. Files, gotchas, and measured performance: docs/omarchy-vm.md.
EOF
}

fail() {
  echo "omarchy-vm: $*" >&2
  echo "run 'just omarchy-vm --help' for usage" >&2
  exit 2
}

cmd_prepare() {
  ensure_directories
  ensure_iso
  ensure_disk
  ensure_ovmf_vars
  echo "== prepare: ready =="
  echo "  iso   $iso_path"
  echo "  disk  $disk_path"
  echo "  vars  $vm_root/OVMF_VARS.fd"
}

cmd_install() {
  local want_gl="$1"
  local foreground="$2"

  confirm_overwrite_install
  cmd_prepare
  echo "== install: booting $iso_version to install interactively =="
  echo "== install: the guest writes to $disk_path =="
  # Record what was installed from. Nothing else knows: the disk cannot be
  # asked without booting it, and "which release is this?" is the first
  # question when a newer one appears.
  printf '%s\n' "$release" >"$vm_root/release"

  # Installs default to software rendering: it is the path the installer was
  # proven on, and a one-time text-mode installer gains nothing from virgl.
  [[ "$want_gl" == "-1" ]] && want_gl=0
  launch_vm "install" "$want_gl" "0" "$foreground"
}

# The script never writes to an existing disk, but the installer inside the
# guest will: it offers to wipe whatever it is attached to. Confirm first, so
# replacing a working system is always a decision rather than a side effect.
confirm_overwrite_install() {
  local bytes
  local answer

  [[ -f "$disk_path" ]] || return 0
  bytes="$(stat -c%s -- "$disk_path")"
  ((bytes >= 100000000)) || return 0

  if [[ "${OMARCHY_ALLOW_REINSTALL:-0}" == "1" ]]; then
    echo "== install: OMARCHY_ALLOW_REINSTALL=1, replacing $disk_path =="
    return 0
  fi

  echo "$disk_path already holds an installed system ($((bytes / 1000000)) MB)."
  echo "Installing $iso_version over it will destroy that system."

  if [[ ! -t 0 ]]; then
    fail "refusing to overwrite without confirmation; no terminal to ask on.
Re-run interactively, or set OMARCHY_ALLOW_REINSTALL=1 to mean it."
  fi

  printf 'Replace it with a fresh %s install? [y/N] ' "$iso_version"
  read -r answer
  case "$answer" in
    y | Y | yes | YES) ;;
    *) fail "install aborted; nothing was changed" ;;
  esac
}

cmd_run() {
  local raw_keyboard="$1"
  local want_gl="$2"
  local foreground="$3"

  require_disk_installed
  ensure_ovmf_vars
  echo "== run: booting the installed disk, no ISO attached =="
  [[ "$want_gl" == "-1" ]] && want_gl=1
  launch_vm "run" "$want_gl" "$raw_keyboard" "$foreground"
}

cmd_status() {
  local pid
  pid="$(read_pid_file)"

  echo "== status =="
  echo "  installed $(installed_release)"
  echo "  newest    $newest_release known to this script"
  echo "  vm root   $vm_root"
  echo "  iso       $iso_path$(path_state "$iso_path")"
  echo "  disk      $disk_path$(path_state "$disk_path")"
  echo "  ovmf vars $vm_root/OVMF_VARS.fd$(path_state "$vm_root/OVMF_VARS.fd")"
  echo "  pid file  $pid_file"
  echo "  monitor   $monitor_socket"

  if [[ -z "$pid" ]]; then
    echo "  state     not running (no PID file)"
    return 0
  fi

  if is_our_qemu "$pid"; then
    echo "  state     RUNNING as PID $pid"
  else
    echo "  state     not running (stale PID file records $pid)"
  fi
}

# Written at install time. A disk installed before this existed, or by hand,
# has no record -- say so rather than guessing.
installed_release() {
  if [[ -f "$vm_root/release" ]]; then
    printf '%s\n' "$(tr -d '[:space:]' <"$vm_root/release")"
  elif [[ -f "$disk_path" ]]; then
    printf 'unknown (installed before this was recorded)\n'
  else
    printf 'nothing installed\n'
  fi
}

cmd_stop() {
  local pid
  local waited

  pid="$(running_pid)" || fail "no running VM to stop; see 'just omarchy-vm status'"

  if [[ ! -S "$monitor_socket" ]]; then
    fail "monitor socket missing: $monitor_socket (use force-stop if the guest is wedged)"
  fi

  echo "== stop: requesting clean ACPI shutdown of PID $pid =="
  monitor_command "system_powerdown"

  for ((waited = 0; waited < 90; waited += 3)); do
    if ! is_our_qemu "$pid"; then
      echo "== stop: guest shut down cleanly after ~${waited}s =="
      return 0
    fi
    sleep 3
  done

  echo "omarchy-vm: guest still running after 90s; it may be ignoring ACPI" >&2
  echo "omarchy-vm: use 'just omarchy-vm force-stop' if it is genuinely wedged" >&2
  return 1
}

cmd_force_stop() {
  local pid

  pid="$(running_pid)" || fail "no running VM to stop; see 'just omarchy-vm status'"

  # Only ever this PID, and only after proving it is this VM's QEMU. A broad
  # pattern kill would take unrelated virtual machines with it.
  echo "== force-stop: killing PID $pid (this VM's QEMU only) =="
  kill -TERM "$pid"
  sleep 3
  if is_our_qemu "$pid"; then
    echo "== force-stop: SIGTERM ignored, sending SIGKILL =="
    kill -KILL "$pid"
  fi
  echo "== force-stop: stopped. The disk may need a filesystem check on boot. =="
}

resolve_paths() {
  select_release
  # Every path is derived from the release, so there is nothing to keep in
  # sync and no way to point an installer at another release's disk.
  vm_root="${OMARCHY_VM_ROOT:-$HOME/vms/omarchy}"
  iso_path="$HOME/isos/omarchy-$release.iso"
  disk_path="$vm_root/omarchy.qcow2"

  require_absolute_path "OMARCHY_VM_ROOT" "$vm_root"

  pid_file="$vm_root/omarchy-vm.pid"
  monitor_socket="$vm_root/omarchy-vm.monitor"
}

require_absolute_path() {
  local name="$1"
  local value="$2"

  [[ -n "$value" ]] || fail "$name must not be empty"
  [[ "$value" == /* ]] || fail "$name must be an absolute path, got: $value"
  [[ "$value" != *$'\n'* ]] || fail "$name must not contain a newline"
}

require_positive_integer() {
  local name="$1"
  local value="$2"

  [[ "$value" =~ ^[1-9][0-9]*$ ]] || fail "$name must be a positive integer, got: $value"
}

ensure_directories() {
  local directory
  for directory in "$vm_root" "$(dirname "$iso_path")" "$(dirname "$disk_path")"; do
    if [[ ! -d "$directory" ]]; then
      echo "== prepare: creating $directory =="
      mkdir -p "$directory"
    fi
  done
}

# Downloads into a .part file and renames only after the hash matches, so an
# interrupted transfer can never be mistaken for a good image.
ensure_iso() {
  local partial="$iso_path.part"

  if [[ -f "$iso_path" ]]; then
    echo "== prepare: verifying existing ISO =="
    verify_iso "$iso_path" || fail "existing ISO failed verification: $iso_path
Refusing to overwrite it. Move or delete it deliberately, then re-run prepare."
    echo "== prepare: ISO verified ($iso_version) =="
    return 0
  fi

  echo "== prepare: downloading $iso_version (about 6 GB) =="
  echo "== prepare: $iso_url =="
  # A progress meter is worth having at a terminal and is pure noise in a log.
  local progress=(--no-progress-meter)
  [[ -t 2 ]] && progress=(--progress-bar)
  curl -fL --retry 3 -C - "${progress[@]}" -o "$partial" "$iso_url" ||
    fail "download failed; the partial file is kept at $partial so a re-run resumes it"

  verify_iso "$partial" || fail "downloaded ISO failed verification; left at $partial"
  mv -- "$partial" "$iso_path"
  echo "== prepare: ISO verified and saved to $iso_path =="
}

verify_iso() {
  local candidate="$1"
  local actual_bytes
  local actual_sha

  actual_bytes="$(stat -c%s -- "$candidate")"
  if [[ "$actual_bytes" != "$iso_bytes" ]]; then
    echo "omarchy-vm: size mismatch: expected $iso_bytes bytes, got $actual_bytes" >&2
    return 1
  fi

  actual_sha="$(sha256sum -- "$candidate" | cut -d' ' -f1)"
  if [[ "$actual_sha" != "$iso_sha256" ]]; then
    echo "omarchy-vm: sha256 mismatch" >&2
    echo "  expected $iso_sha256" >&2
    echo "  actual   $actual_sha" >&2
    return 1
  fi
}

# Never replaces, truncates, or recreates an existing disk: it holds the
# installed guest, and re-running prepare must not be able to destroy it.
ensure_disk() {
  local size="${OMARCHY_DISK_SIZE:-120G}"
  local qemu_img

  if [[ -f "$disk_path" ]]; then
    echo "== prepare: keeping existing disk $disk_path =="
    return 0
  fi

  [[ "$size" =~ ^[1-9][0-9]*[MGT]$ ]] || fail "OMARCHY_DISK_SIZE must look like 120G, got: $size"
  qemu_img="$(resolve_qemu)/bin/qemu-img"
  echo "== prepare: creating sparse disk $disk_path ($size) =="
  "$qemu_img" create -f qcow2 "$disk_path" "$size"
}

# The OVMF code image is immutable and shared; only the per-VM variables file
# is writable, and it is copied once so UEFI boot entries survive reboots.
ensure_ovmf_vars() {
  local vars="$vm_root/OVMF_VARS.fd"
  local ovmf

  if [[ -f "$vars" ]]; then
    return 0
  fi

  ovmf="$(resolve_ovmf)"
  echo "== prepare: seeding UEFI variables $vars =="
  cp -- "$ovmf/FV/OVMF_VARS.fd" "$vars"
  chmod u+w -- "$vars"
}

require_disk_installed() {
  [[ -f "$disk_path" ]] ||
    fail "no disk at $disk_path; run 'just omarchy-vm install' first"

  # A freshly created qcow2 is a few hundred KiB. Anything that small has no
  # operating system on it, and booting it just drops the user at a UEFI shell.
  local bytes
  bytes="$(stat -c%s -- "$disk_path")"
  if ((bytes < 100000000)); then
    fail "disk at $disk_path looks empty ($bytes bytes); run 'just omarchy-vm install' first"
  fi
}

launch_vm() {
  local mode="$1"
  local want_gl="$2"
  local want_raw_keyboard="$3"
  local foreground="$4"
  local qemu
  local ovmf
  local smp="${OMARCHY_SMP:-4}"
  local memory="${OMARCHY_MEMORY:-8192}"
  local xres=1920
  local yres=1080

  require_positive_integer "OMARCHY_SMP" "$smp"
  require_positive_integer "OMARCHY_MEMORY" "$memory"

  refuse_if_running
  require_display

  qemu="$(resolve_qemu)"
  ovmf="$(resolve_ovmf)"

  local media=()
  if [[ "$mode" == "install" ]]; then
    media=(-drive "file=$iso_path,media=cdrom,readonly=on")
  fi

  # virtio-vga-gl hands the guest's GL calls to the host GPU. Without it the
  # guest falls back to software rendering, which is usable but roughly four
  # times slower; see docs/omarchy-vm.md for measured numbers.
  local video=(-device "virtio-vga,xres=$xres,yres=$yres")
  local display=(-display "gtk,zoom-to-fit=off")
  if [[ "$want_gl" == "1" ]]; then
    video=(-device "virtio-vga-gl,xres=$xres,yres=$yres")
    display=(-display "gtk,zoom-to-fit=off,gl=on")
  fi

  local keyboard=()
  local captured=false
  if [[ "$want_raw_keyboard" == "1" ]]; then
    local evdev
    evdev="$(find_keyd_evdev)"
    keyboard=(-object "input-linux,id=kbd0,evdev=$evdev,grab_all=on,repeat=on")
    captured=true
    echo "== $mode: capturing $evdev ($keyd_device_name) =="
  fi

  print_hotkeys "$captured"

  qemu_command=(
    "$qemu/bin/qemu-system-x86_64"
    -enable-kvm -machine q35 -cpu host -smp "$smp" -m "$memory"
    -drive "if=pflash,format=raw,readonly=on,file=$ovmf/FV/OVMF_CODE.fd"
    -drive "if=pflash,format=raw,file=$vm_root/OVMF_VARS.fd"
    -drive "file=$disk_path,if=virtio,format=qcow2"
    "${media[@]}"
    "${video[@]}"
    -device qemu-xhci -device usb-tablet -device virtio-keyboard
    -netdev "user,id=n0" -device "virtio-net-pci,netdev=n0"
    "${keyboard[@]}"
    "${display[@]}"
    -monitor "unix:$monitor_socket,server,nowait"
    -name "$iso_version"
  )

  rm -f -- "$monitor_socket"
  if [[ "$foreground" == "1" ]]; then
    run_in_foreground "$mode"
  else
    run_detached "$mode"
  fi
}

# Blocks until the guest exits. Useful when watching a first install, or when
# something is going wrong and the QEMU output should land on the terminal.
run_in_foreground() {
  local mode="$1"
  local status=0

  start_idle_inhibitor
  trap release_vm_resources EXIT INT TERM

  "${qemu_command[@]}" &
  qemu_pid=$!
  printf '%s\n' "$qemu_pid" >"$pid_file"
  echo "== $mode: QEMU running as PID $qemu_pid (foreground) =="

  wait "$qemu_pid" || status=$?
  qemu_pid=""
  return "$status"
}

# The default. A desktop VM outlives the terminal that started it, so hand the
# prompt back. A supervisor subshell keeps holding the idle inhibitor and
# clears the PID file and socket when the guest finally exits -- work that
# would otherwise never happen, since nothing is left waiting on it.
run_detached() {
  local mode="$1"
  local log="$vm_root/omarchy-vm.log"
  local pid

  (
    trap '' HUP
    exec >>"$log" 2>&1
    start_idle_inhibitor
    trap release_vm_resources EXIT
    "${qemu_command[@]}" &
    # Deliberately the subshell's own copy: this subshell owns the VM and its
    # EXIT trap is what releases it.
    # shellcheck disable=SC2030
    qemu_pid=$!
    printf '%s\n' "$qemu_pid" >"$pid_file"
    wait "$qemu_pid"
  ) &
  disown 2>/dev/null || true

  # Surface an immediate failure rather than returning a prompt and a VM that
  # is already gone.
  sleep 3
  pid="$(read_pid_file)"
  if [[ -z "$pid" ]] || ! is_our_qemu "$pid"; then
    echo "omarchy-vm: the VM exited immediately. Last lines of $log:" >&2
    tail -n 15 -- "$log" >&2 2>/dev/null || true
    return 1
  fi

  echo "== $mode: running as PID $pid; this terminal is free =="
  echo "   stop it with:  just omarchy-vm stop"
  echo "   log:           $log"
}

# Three different releases, easily confused. Both-Ctrl is QEMU's own toggle for
# input-linux and only exists when the keyboard is captured; the Ctrl+Alt pair
# are GTK's and always apply.
print_hotkeys() {
  local captured="$1"

  if [[ "$captured" == true ]]; then
    cat <<'EOF'

  Both Ctrl keys   toggle keyboard capture (left-Ctrl + right-Ctrl together)
                   While captured, this host has no keyboard at all. That is
                   the point, and it is also why the two keys below do NOT
                   work until you release capture: every key goes to the guest,
                   so GTK never sees its own shortcuts.

  Release capture FIRST, then use:
EOF
  fi

  cat <<'EOF'
  Ctrl+Alt+F       toggle fullscreen (how you get the menu bar back)
  Ctrl+Alt+G       release the mouse grab

  Leave "Zoom to Fit" OFF in the View menu. With it on, QEMU scales a small
  guest framebuffer up to the window: bigger, blurrier, and exactly the same
  number of text rows. With it off, resizing the window resizes the guest.

  Avoid fullscreen while the keyboard is captured: a tiling workspace can
  scroll the window out of view, and you cannot type to get back to it.
  If you end up stuck, from any other shell:
    just omarchy-vm stop         clean guest shutdown
    just omarchy-vm force-stop   last resort
    loginctl unlock-session <id> if the host lock screen is in the way

EOF
}

# Resolves by device NAME, never by a fixed event number: those are assigned in
# discovery order and move between boots. A wrong node would hand the guest the
# lid switch, or capture nothing at all.
find_keyd_evdev() {
  local node=""
  local name=""
  local handlers
  local candidate

  while IFS= read -r line; do
    case "$line" in
      "N: Name="*)
        name="${line#N: Name=\"}"
        name="${name%\"}"
        ;;
      "H: Handlers="*)
        if [[ "$name" == "$keyd_device_name" ]]; then
          handlers="${line#H: Handlers=}"
          for candidate in $handlers; do
            if [[ "$candidate" == event* ]]; then
              node="/dev/input/$candidate"
              break
            fi
          done
        fi
        ;;
    esac
    [[ -n "$node" ]] && break
  done </proc/bus/input/devices

  if [[ -z "$node" ]]; then
    fail "no input device named '$keyd_device_name' found.
Is keyd running? Check: systemctl status keyd
Run with --no-raw-keyboard to start without keyboard capture."
  fi

  # Re-check the name at the resolved node. Between enumeration and use the
  # numbering could differ; capturing the wrong device is worse than not
  # capturing at all, and falling back to a physical keyboard is never correct.
  verify_evdev_name "$node" ||
    fail "device $node is not '$keyd_device_name'; refusing to capture it"

  if [[ ! -r "$node" ]]; then
    fail "cannot read $node.
Grant access for this boot with:
  sudo setfacl -m u:$USER:rw $node
Or run with --no-raw-keyboard to start without keyboard capture."
  fi

  printf '%s\n' "$node"
}

verify_evdev_name() {
  local node="$1"
  local wanted="${node#/dev/input/}"
  local name=""

  while IFS= read -r line; do
    case "$line" in
      "N: Name="*)
        name="${line#N: Name=\"}"
        name="${name%\"}"
        ;;
      "H: Handlers="*)
        if [[ " ${line#H: Handlers=} " == *" $wanted "* ]]; then
          [[ "$name" == "$keyd_device_name" ]]
          return
        fi
        ;;
    esac
  done </proc/bus/input/devices

  return 1
}

# While the keyboard is captured this host sees no input at all, so its idle
# timer fires and locks a screen that cannot then be typed into. Hold an
# inhibitor for the VM's lifetime instead.
start_idle_inhibitor() {
  if ! command -v systemd-inhibit >/dev/null 2>&1; then
    return 0
  fi

  # idle only, never sleep: blocking sleep is gated behind polkit's
  # inhibit-block-sleep (auth_admin_keep) and prompts for a password on every
  # launch, while blocking idle is unprivileged. Idle is all that is needed --
  # the problem being solved is the host locking a screen that cannot then be
  # typed into, not the host suspending.
  systemd-inhibit --what=idle --who="omarchy-vm" \
    --why="Omarchy VM running with the keyboard captured" \
    --mode=block sleep infinity &
  inhibit_pid=$!
}

# Removes only what this script created. The ISO, the disk, and the UEFI
# variables are the valuable artifacts and are never touched here.
#
# Runs as an EXIT trap in whichever shell owns the VM: the script itself when
# foreground, the supervisor subshell when detached. Each sees the qemu_pid its
# own shell set, which is the intent -- hence the disable below.
# shellcheck disable=SC2030,SC2031
release_vm_resources() {
  if [[ -n "$inhibit_pid" ]] && kill -0 "$inhibit_pid" 2>/dev/null; then
    kill "$inhibit_pid" 2>/dev/null || true
  fi
  inhibit_pid=""

  if [[ -n "$qemu_pid" ]] && kill -0 "$qemu_pid" 2>/dev/null; then
    kill -TERM "$qemu_pid" 2>/dev/null || true
  fi

  rm -f -- "$pid_file" "$monitor_socket"
}

refuse_if_running() {
  local pid
  pid="$(read_pid_file)"

  [[ -n "$pid" ]] || return 0

  if is_our_qemu "$pid"; then
    fail "this VM is already running as PID $pid.
Two QEMU processes sharing one disk will corrupt it.
Stop it with 'just omarchy-vm stop' first."
  fi

  # Only now, having proved no such process exists, is the file stale.
  echo "== clearing stale PID file (no process $pid) =="
  rm -f -- "$pid_file"
}

running_pid() {
  local pid
  pid="$(read_pid_file)"

  [[ -n "$pid" ]] || return 1
  is_our_qemu "$pid" || return 1
  printf '%s\n' "$pid"
}

read_pid_file() {
  local pid

  [[ -f "$pid_file" ]] || return 0
  pid="$(tr -d '[:space:]' <"$pid_file")"
  [[ "$pid" =~ ^[1-9][0-9]*$ ]] || return 0
  printf '%s\n' "$pid"
}

# A PID alone proves nothing: numbers are reused. Confirm the process really is
# this VM's QEMU before reporting it as running, and before ever signalling it.
is_our_qemu() {
  local pid="$1"
  local cmdline

  [[ -r "/proc/$pid/cmdline" ]] || return 1
  cmdline="$(tr '\0' ' ' <"/proc/$pid/cmdline")"
  [[ "$cmdline" == *qemu-system-x86_64* ]] || return 1
  [[ "$cmdline" == *"$disk_path"* ]] || return 1
}

monitor_command() {
  local command="$1"
  local socat

  socat="$(resolve_tool socat)/bin/socat"
  printf '%s\n' "$command" | "$socat" - "UNIX-CONNECT:$monitor_socket" >/dev/null
}

path_state() {
  [[ -e "$1" ]] && echo "" || echo "  (absent)"
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

  fail "no graphical session found under $runtime_dir.
This opens a window, so run it from a terminal inside your desktop."
}

resolve_qemu() {
  resolve_tool qemu
}

resolve_ovmf() {
  resolve_tool OVMF.fd
}

# Takes tools from the repository's locked nixpkgs input, so they match what the
# flake already pins and nothing is installed into the host configuration.
resolve_tool() {
  local attribute="$1"
  local repository
  repository="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

  nix build --inputs-from "$repository" "nixpkgs#$attribute" \
    --no-link --print-out-paths 2>/dev/null ||
    fail "could not resolve $attribute from the locked nixpkgs input"
}

main "$@"
