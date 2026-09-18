{ config, ... }:
{
  flake.modules.nixos.locale = {
    time.timeZone = "America/Toronto";
    i18n.defaultLocale = "en_CA.UTF-8";
  };
  flake.modules.nixos.base.imports = [ config.flake.modules.nixos.locale ];
}
