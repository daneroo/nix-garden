# The GNOME session itself: display manager, desktop, input, audio, printing,
# and the shell's own dconf keys. Session-agnostic applications live in the
# desktop aspect; a second desktop becomes a sibling aspect of `gnome`.
{ config, ... }:
{
  flake.modules.nixos.gnome-session =
    { config, lib, ... }:
    {
      services.xserver.enable = true;
      services.displayManager.gdm.enable = true;
      services.desktopManager.gnome.enable = true;
      services.xserver.xkb = {
        layout = "us";
        variant = "";
      };

      services.printing.enable = true;

      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
      };

      programs.dconf.enable = true;

      # The GNOME dconf database is split by owner: every feature contributes
      # its own database with its own key paths, and this feature owns
      # `org/gnome/shell`, naming the extensions that keyd-gnome-extension and
      # paperwm install. dconf lookup is first-wins per key across the
      # profile's databases, so the split is only safe while the key paths
      # stay disjoint; the assertion below fails evaluation otherwise.
      programs.dconf.profiles.user.databases = [
        {
          settings = {
            "org/gnome/shell" = {
              # GNOME hides Log Out for a single local user with a single
              # session type, which both hosts are: GNOME 50 dropped the Xorg
              # session, so `sessionData.desktops` holds only `gnome.desktop`.
              always-show-log-out = true;
              enabled-extensions = [
                "keyd@keyd.rvaiya.github.com"
                "paperwm@paperwm.github.com"
              ];
              # Pinned to the dash 2026-07-23; Files (Nautilus) was already
              # there as a GNOME default, kept alongside Ghostty and Brave.
              favorite-apps = [
                "com.mitchellh.ghostty.desktop"
                "brave-browser.desktop"
                "org.gnome.Nautilus.desktop"
              ];
            };
            "org/gnome/desktop/peripherals/mouse" = {
              # Matches Daniel's macOS-trained scroll expectation.
              natural-scroll = true;
            };
          };
        }
      ];

      assertions =
        let
          settingsDatabases = builtins.filter (
            db: builtins.isAttrs db && db ? settings
          ) config.programs.dconf.profiles.user.databases;
          keyPaths = lib.concatMap (db: builtins.attrNames db.settings) settingsDatabases;
          duplicates = lib.unique (builtins.filter (p: lib.count (q: q == p) keyPaths > 1) keyPaths);
        in
        [
          {
            assertion = duplicates == [ ];
            message = ''
              programs.dconf.profiles.user.databases: the key path(s)
              ${lib.concatStringsSep ", " duplicates} are defined by more than one
              database. dconf lookup is first-wins per key, so give each key path
              exactly one owning feature.
            '';
          }
        ];
    };
  flake.modules.nixos.gnome.imports = [ config.flake.modules.nixos.gnome-session ];
}
