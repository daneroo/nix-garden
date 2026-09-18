# The single interactive user of this fleet. Features that need Daniel by name
# (nh's flake path, 1Password's polkit owners) say so where they do it; that
# coupling is accepted for a single-user fleet and documented, not abstracted.
{ config, ... }:
{
  flake.modules.nixos.user-daniel = {
    users.users.daniel = {
      isNormalUser = true;
      description = "Daniel Lauzon";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrUdJY3Aj0Xi2zdlGrEHFv3FNnlMz6ASLclhhl9cj1p daniel@galois"
      ];
    };

    # Temporary for agent-driven work on non-production hosts. Require
    # passwords again before a host carries important workloads.
    security.sudo.wheelNeedsPassword = false;

    # Stopgap. System tmpfiles writing beneath /home/daniel is what
    # `home-config-ownership` in the backlog exists to delete; until then this
    # feature owns the XDG skeleton and each feature owns the subdirectory and
    # `L+` lines for its own files. Keep the list from creeping.
    #
    # Every parent directory is declared explicitly, and must stay that way.
    # systemd-tmpfiles refuses to descend a path whose ownership changes -- a
    # symlink-attack guard -- and materialising a parent implicitly creates it
    # as root. On a home that already contains daniel-owned .config and .local
    # the rules work by luck; on a fresh one tmpfiles creates a root-owned
    # .config, then its own guard makes it skip every L+ beneath, silently and
    # without failing the unit. Found 2026-07-25 in the test-harness VM, where
    # none of the managed dotfiles existed: "Detected unsafe path transition
    # /home/daniel (owned by daniel) -> /home/daniel/.config (owned by root)".
    # A reinstall of either host would have hit the same thing.
    #
    # Modes match what the running systems already had, so applying this
    # changes no existing permissions: XDG wants 0700 on .config and
    # .local/share.
    systemd.tmpfiles.rules = [
      "d /home/daniel/.config 0700 daniel users -"
      "d /home/daniel/.local 0755 daniel users -"
      "d /home/daniel/.local/share 0700 daniel users -"
    ];
  };
  flake.modules.nixos.base.imports = [ config.flake.modules.nixos.user-daniel ];
}
