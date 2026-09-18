# Network connectivity and the home domain. The hostname is identity and stays
# in each host file.
{ config, ... }:
{
  flake.modules.nixos.networkmanager = {
    networking.networkmanager.enable = true;
    networking.domain = "imetrical.com";
  };
  flake.modules.nixos.base.imports = [ config.flake.modules.nixos.networkmanager ];
}
