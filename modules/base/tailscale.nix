{ config, ... }:
{
  flake.modules.nixos.tailscale = {
    services.tailscale.enable = true;
  };
  flake.modules.nixos.base.imports = [ config.flake.modules.nixos.tailscale ];
}
