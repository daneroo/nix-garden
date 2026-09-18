# The Vicinae launcher. No NixOS module ships for it (only a Home Manager one,
# which this repo isn't adopting -- see feedback_defer_home_manager), so the
# package and its user service are declared here. "vicinae toggle" (bound to
# Alt+Space by gnome-keybindings) needs the server already running to have
# anything to toggle.
{ config, ... }:
{
  flake.modules.nixos.vicinae =
    { pkgs, ... }:
    {
      environment.systemPackages = [ pkgs.vicinae ];

      systemd.user.services.vicinae = {
        description = "Vicinae launcher server";
        wantedBy = [ "graphical-session.target" ];
        partOf = [ "graphical-session.target" ];
        # Vicinae 0.28 launches an app's desktop-file Exec= command by
        # spawning it directly (execve on the bare command name) rather than
        # going through GNOME's desktop-file activation, so it depends on its
        # own process PATH rather than the login session's. The systemd
        # module's default unit PATH is a minimal coreutils/findutils/
        # gnugrep/gnused/systemd set; without this, launching any installed
        # application (e.g. "ghostty --gtk-single-instance=true") fails with
        # "execve: No such file or directory". Found 2026-09-18 after the
        # 0.23.2 -> 0.28.1 bump; the service definition itself was unchanged.
        path = [ "/run/current-system/sw" ];
        serviceConfig = {
          ExecStart = "${pkgs.vicinae}/bin/vicinae server";
          Restart = "on-failure";
        };
      };
    };
  flake.modules.nixos.desktop.imports = [ config.flake.modules.nixos.vicinae ];
}
