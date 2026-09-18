{ config, ... }:
{
  flake.modules.nixos.systemd-boot = {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    # Bound the boot menu and let a failed generation fall back on its own;
    # see docs/workspace.md. Retention is by recency, not by known-good -- the
    # generation-gc ticket owns that and store space.
    boot.loader.systemd-boot = {
      configurationLimit = 20;
      bootCounting.enable = true;
    };
  };
  flake.modules.nixos.base.imports = [ config.flake.modules.nixos.systemd-boot ];
}
