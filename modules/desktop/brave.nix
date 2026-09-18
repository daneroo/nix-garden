# Brave as the default browser, and its keyd application map. The package is
# in cli-baseline.
{ config, ... }:
{
  flake.modules.nixos.brave =
    { pkgs, ... }:
    let
      # Brave uses Ctrl for these actions. Translate native Alt only while
      # Brave has focus, preserving native Alt and Ctrl everywhere else.
      keydAppConf = pkgs.writeText "keyd-app.conf" ''
        [brave-browser]

        alt.c = C-c
        alt.v = C-v
        alt.t = C-t
        alt.w = C-w
        alt+shift.t = C-S-t
        alt.n = C-n
        alt.l = C-l
        alt.f = C-f
        alt+shift.rightbrace = C-tab
        alt+shift.leftbrace = C-S-tab
        # Alt+L is translated above, so preserve GNOME's overlapping lock chord.
        alt+shift.l = A-S-l
      '';
    in
    {
      xdg.mime.defaultApplications = {
        "text/html" = "brave-browser.desktop";
        "x-scheme-handler/http" = "brave-browser.desktop";
        "x-scheme-handler/https" = "brave-browser.desktop";
        "x-scheme-handler/about" = "brave-browser.desktop";
        "x-scheme-handler/unknown" = "brave-browser.desktop";
      };

      # Stopgap; the XDG parents are owned by user-daniel, which explains why
      # every parent must be declared explicitly.
      systemd.tmpfiles.rules = [
        "d /home/daniel/.config/keyd 0755 daniel users -"
        "L+ /home/daniel/.config/keyd/app.conf - - - - ${keydAppConf}"
      ];
    };
  flake.modules.nixos.desktop.imports = [ config.flake.modules.nixos.brave ];
}
