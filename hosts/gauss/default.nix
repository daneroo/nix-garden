{ pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "gauss";

  # gnome-console (GTK "Terminal") is confusable with Ghostty, the actual
  # target terminal for keybinding-model work; drop it from the default set.
  environment.gnome.excludePackages = [ pkgs.gnome-console ];

  services.keyd = {
    keyboards.default = {
      ids = [ "*" ];
      # keyd-application-mapper cannot dynamically bind a composite layer
      # unless the static config declares it first. No base modifier mapping:
      # Alt, Ctrl, both Windows-logo keys, and right Alt/AltGr stay native.
      settings."alt+shift" = { };
    };
  };

  systemd.services.keyd.serviceConfig = {
    # Upstream's docs assume a dedicated "keyd" group (usermod -aG keyd);
    # the NixOS module doesn't create one. Using "users" instead -- daniel's
    # existing primary group -- means socket access works without daniel
    # needing a fresh login to pick up new group membership.
    Group = lib.mkForce "users";
  };

  # gauss is an always-on homelab box, not a laptop; never suspend.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  users.users.daniel = {
    # Keeps user services (e.g. Herdr's server) running independent of an
    # active login session -- set imperatively via `loginctl enable-linger`
    # during keybinding-model work to survive a GNOME logout/login cycle
    # needed to refresh Shell's app-grid file watchers; encoded here so it
    # isn't lost on a future reinstall.
    linger = true;
  };

  system.stateVersion = "26.05";
}
