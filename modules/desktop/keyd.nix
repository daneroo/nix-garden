# keyd runs on every desktop host, but what it manages is a host declaration:
# `services.keyd.keyboards`, the `alt+shift` layer inside each keyboard, and
# the socket group model (hardy uses a dedicated `keyd` group with CAP_SETGID;
# gauss uses the broad `users` group) all live in the host files, each with
# the reason. This feature owns only what is identical.
{ config, ... }:
{
  flake.modules.nixos.keyd =
    { lib, pkgs, ... }:
    {
      services.keyd.enable = true;

      # A group-readable socket, whichever group the host chooses.
      systemd.services.keyd.serviceConfig.UMask = lib.mkForce "0007";

      # keyd-application-mapper needs to be resolvable via PATH by whatever
      # spawns it (the GNOME Shell extension); adding it here (rather than only
      # via the keyd systemd service's own ExecStart) makes it findable through
      # the per-user profile, which existing long-running processes' PATH
      # entries already include -- unlike a brand-new PATH entry, this doesn't
      # require a fresh login to take effect.
      users.users.daniel.packages = [ pkgs.keyd ];
    };
  flake.modules.nixos.desktop.imports = [ config.flake.modules.nixos.keyd ];
}
