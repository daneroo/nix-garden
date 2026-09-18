# The machine inventory: which hosts exist and how each one is composed.
# `nixosConfigurations` is defined here and nowhere else.
{
  config,
  inputs,
  lib,
  ...
}:
let
  hosts = [
    "hardy"
    "gauss"
  ];

  nixos = config.flake.modules.nixos;
in
{
  flake.modules.nixos = lib.genAttrs' hosts (name: {
    name = "host-${name}";
    value = {
      imports = [
        (./. + "/${name}")
        nixos.e2e-injection
        nixos.paperwm
        # Inert in a normal system/test build; used by `nixos-rebuild
        # build-vm`.
        nixos.vm-variant
        nixos.base
        {
          # Moves to the brave feature with the desktop aspect.
          xdg.mime.defaultApplications = {
            "text/html" = "brave-browser.desktop";
            "x-scheme-handler/http" = "brave-browser.desktop";
            "x-scheme-handler/https" = "brave-browser.desktop";
            "x-scheme-handler/about" = "brave-browser.desktop";
            "x-scheme-handler/unknown" = "brave-browser.desktop";
          };
        }
      ];
    };
  });

  flake.nixosConfigurations = lib.genAttrs hosts (
    name:
    inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ nixos."host-${name}" ];
    }
  );
}
