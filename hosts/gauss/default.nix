# gauss: the SER8 always-on homelab desktop. Hardware, the three aspects,
# identity, and the exceptions below; everything else is a feature under
# modules/.
{ config, ... }:
{
  flake.modules.nixos.host-gauss =
    { lib, pkgs, ... }:
    {
      imports = [
        ./hardware-configuration.nix
        config.flake.modules.nixos.base
        config.flake.modules.nixos.desktop
        config.flake.modules.nixos.gnome
      ];

      networking.hostName = "gauss";
      system.stateVersion = "26.05";

      # A standard keyboard: keyd manages every device with no base modifier
      # mapping, so Alt, Ctrl, both Windows-logo keys, and right Alt/AltGr stay
      # native.
      services.keyd.keyboards.default = {
        ids = [ "*" ];
        # keyd-application-mapper cannot dynamically bind a composite layer
        # unless the static config declares it first.
        settings."alt+shift" = { };
      };

      # Upstream's docs assume a dedicated "keyd" group (usermod -aG keyd); the
      # NixOS module doesn't create one. Using "users" instead -- daniel's
      # existing primary group -- means socket access works without daniel
      # needing a fresh login to pick up new group membership. The
      # keyd-socket-permissions backlog item replaces this with a dedicated
      # group, as hardy already has.
      systemd.services.keyd.serviceConfig.Group = lib.mkForce "users";

      # gnome-console (GTK "Terminal") is confusable with Ghostty, the actual
      # target terminal for keybinding-model work; drop it from the default
      # set.
      environment.gnome.excludePackages = [ pkgs.gnome-console ];

      # An always-on homelab box, not a laptop; never suspend.
      systemd.targets.sleep.enable = false;
      systemd.targets.suspend.enable = false;
      systemd.targets.hibernate.enable = false;
      systemd.targets.hybrid-sleep.enable = false;

      # Keeps user services (e.g. Herdr's server) running independent of an
      # active login session -- set imperatively via `loginctl enable-linger`
      # during keybinding-model work to survive a GNOME logout/login cycle
      # needed to refresh Shell's app-grid file watchers; encoded here so it
      # isn't lost on a future reinstall.
      users.users.daniel.linger = true;
    };
}
