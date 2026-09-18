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
        serviceConfig = {
          ExecStart = "${pkgs.vicinae}/bin/vicinae server";
          Restart = "on-failure";
        };
      };
    };
  flake.modules.nixos.desktop.imports = [ config.flake.modules.nixos.vicinae ];
}
