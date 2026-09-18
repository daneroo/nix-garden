# Key-only SSH; the authorized keys belong to the user feature.
{ config, ... }:
{
  flake.modules.nixos.openssh = {
    services.openssh = {
      enable = true;
      openFirewall = true;
      settings = {
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
  };
  flake.modules.nixos.base.imports = [ config.flake.modules.nixos.openssh ];
}
