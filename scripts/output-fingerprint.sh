#!/usr/bin/env bash
set -euo pipefail

# Fingerprint the public flake outputs of one revision without its Git identity,
# so two revisions can be compared for preserved behavior.
#
# The tree is exported and evaluated as a `path:` flake. A path flake has no
# `rev` or `dirtyRev`, so `system.configurationRevision` becomes the literal
# "dirty" for every revision and no longer perturbs derivation hashes. Equal
# derivation paths therefore mean equal outputs; when they differ, the semantic
# section names the configuration values that moved, and `nix-diff` explains
# the rest:
#
#   nix run --inputs-from . nixpkgs#nix-diff -- OLD.drv NEW.drv

main() {
  local selector="${1:-HEAD}"
  local repo_root
  repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

  case "$selector" in
    -h | --help)
      usage
      return
      ;;
  esac
  if (($# > 1)); then
    fail "expected at most one selector"
  fi

  tree="$(mktemp -d)"
  trap 'rm -rf -- "$tree"' EXIT
  export_tree "$repo_root" "$selector" "$tree"
  local flake="path:$tree"

  echo "# selector: $selector"
  echo "# outputs"
  list_outputs "$flake" | sed 's/^/output /'

  local host
  for host in $(nixos_configuration_names "$flake"); do
    echo "# nixosConfigurations.$host"
    printf 'toplevel %s %s\n' "$host" \
      "$(nix eval --raw "$flake#nixosConfigurations.$host.config.system.build.toplevel.drvPath")"
    printf 'configurationRevision %s %s\n' "$host" \
      "$(nix eval --raw "$flake#nixosConfigurations.$host.config.system.configurationRevision")"
    nix eval --json "$flake#nixosConfigurations.$host.config" --apply "$semantic" |
      jq -S . | sed "s/^/semantic $host /"
  done

  local package
  for package in $(list_outputs "$flake" | grep '^packages\.' || true); do
    printf 'drv %s %s\n' "$package" "$(nix eval --raw "$flake#$package.drvPath")"
  done
}

usage() {
  cat <<'USAGE'
Usage:
  scripts/output-fingerprint.sh [REV | WORKTREE]

  REV       any Git revision (default HEAD), exported with `git archive`
  WORKTREE  the tracked files of the working tree, including uncommitted edits

Compare two revisions:
  diff <(scripts/output-fingerprint.sh main) <(scripts/output-fingerprint.sh WORKTREE)
USAGE
}

fail() {
  echo "output-fingerprint: $*" >&2
  exit 2
}

export_tree() {
  local repo_root="$1"
  local selector="$2"
  local tree="$3"

  if [[ "$selector" == "WORKTREE" ]]; then
    git -C "$repo_root" ls-files -z |
      tar -cf - -C "$repo_root" --null -T - |
      tar -xf - -C "$tree"
  else
    git -C "$repo_root" rev-parse --verify --quiet "$selector^{commit}" >/dev/null ||
      fail "unknown revision '$selector'"
    git -C "$repo_root" archive "$selector" | tar -xf - -C "$tree"
  fi
}

# Every attribute path `nix flake show` recognizes as an output, one per line.
# Nix 2.35 nests outputs under `inventory`/`output`/`children` with a `what`
# leaf; Nix 2.34 emits the plain tree with a `type` leaf. Accept both.
list_outputs() {
  local flake="$1"
  nix flake show --json --all-systems "$flake" 2>/dev/null |
    jq -r '
      [ paths(type == "object" and (has("what") or (has("type") and (.type | type) == "string")))
        | map(select(. != "inventory" and . != "output" and . != "children"))
        | join(".") ]
      | sort[]'
}

nixos_configuration_names() {
  local flake="$1"
  nix eval --json "$flake#nixosConfigurations" --apply builtins.attrNames |
    jq -r '.[]'
}

# Order-independent view of the configuration values this repository owns.
# Extend it when a refactor touches something it does not yet cover.
semantic='
c:
let
  sort = builtins.sort builtins.lessThan;
  names = a: sort (builtins.attrNames a);
  packageNames = ps: sort (map (p: p.name) ps);
  normalUsers = builtins.filter (n: c.users.users.${n}.isNormalUser)
    (builtins.attrNames c.users.users);
in
{
  hostName = c.networking.hostName;
  domain = c.networking.domain;
  stateVersion = c.system.stateVersion;
  timeZone = c.time.timeZone;
  locale = c.i18n.defaultLocale;
  bootLoader = {
    systemdBoot = c.boot.loader.systemd-boot.enable;
    configurationLimit = c.boot.loader.systemd-boot.configurationLimit;
    bootCounting = c.boot.loader.systemd-boot.bootCounting.enable;
    canTouchEfiVariables = c.boot.loader.efi.canTouchEfiVariables;
  };
  networkmanager = c.networking.networkmanager.enable;
  tailscale = c.services.tailscale.enable;
  openssh = { inherit (c.services.openssh) enable openFirewall settings; };
  firewallTcp = sort c.networking.firewall.allowedTCPPorts;
  sudoWheelNeedsPassword = c.security.sudo.wheelNeedsPassword;
  nix = { experimentalFeatures = c.nix.settings.experimental-features; allowUnfree = c.nixpkgs.config.allowUnfree or null; };
  nh = { inherit (c.programs.nh) enable flake; };
  desktop = {
    xserver = c.services.xserver.enable;
    gdm = c.services.displayManager.gdm.enable;
    gnome = c.services.desktopManager.gnome.enable;
    xkb = { inherit (c.services.xserver.xkb) layout variant; };
    gnomeExcluded = packageNames c.environment.gnome.excludePackages;
    printing = c.services.printing.enable;
    pipewire = { inherit (c.services.pipewire) enable; alsa = c.services.pipewire.alsa.enable; pulse = c.services.pipewire.pulse.enable; };
    rtkit = c.security.rtkit.enable;
    pulseaudio = c.services.pulseaudio.enable;
    dconfEnabled = c.programs.dconf.enable;
    onePasswordGui = { inherit (c.programs._1password-gui) enable polkitPolicyOwners; };
    onePasswordCli = c.programs._1password.enable;
    ydotool = c.programs.ydotool.enable;
    mime = c.xdg.mime.defaultApplications;
  };
  dconf = map (db: db.settings) c.programs.dconf.profiles.user.databases;
  keyd = {
    enable = c.services.keyd.enable;
    keyboards = builtins.mapAttrs (_: k: { inherit (k) ids settings extraConfig; }) c.services.keyd.keyboards;
    service = c.systemd.services.keyd.serviceConfig;
  };
  systemPackages = packageNames c.environment.systemPackages;
  users = builtins.listToAttrs (map (n: {
    name = n;
    value = {
      inherit (c.users.users.${n}) description extraGroups linger;
      packages = packageNames c.users.users.${n}.packages;
      authorizedKeys = c.users.users.${n}.openssh.authorizedKeys.keys;
      passwordSet = c.users.users.${n}.password != null;
    };
  }) normalUsers);
  groups = names c.users.groups;
  etc = builtins.mapAttrs (_: e: e.source) c.environment.etc;
  tmpfiles = sort c.systemd.tmpfiles.rules;
  services = names c.systemd.services;
  userServices = names c.systemd.user.services;
  disabledTargets = sort (builtins.filter (n: !c.systemd.targets.${n}.enable) (builtins.attrNames c.systemd.targets));
  vmVariant = {
    autoLogin = c.virtualisation.vmVariant.services.displayManager.autoLogin.enable;
    memorySize = c.virtualisation.vmVariant.virtualisation.memorySize;
  };
}
'

main "$@"
