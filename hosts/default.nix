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
        nixos.paperwm
        nixos.base
        nixos.desktop
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
