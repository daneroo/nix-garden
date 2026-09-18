# The machine inventory: which hosts exist, each defined by its own directory
# as modules.nixos.host-<name>. `nixosConfigurations` is defined here and
# nowhere else. Hosts are listed explicitly because the generated
# hardware-configuration.nix files must not be auto-imported.
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
in
{
  imports = map (name: ./. + "/${name}") hosts;

  flake.nixosConfigurations = lib.genAttrs hosts (
    name:
    inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ config.flake.modules.nixos."host-${name}" ];
    }
  );
}
