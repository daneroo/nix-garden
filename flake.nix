{
  description = "Reproducible system config for the homelab fleet";

  inputs = {
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    herdr.url = "github:herdrdev/herdr/v0.9.0";
    import-tree.url = "github:denful/import-tree";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  # Everything else is a flake-parts module: every file under modules/ is
  # imported by import-tree, and hosts/ is the explicit machine inventory.
  # See docs/module-architecture.md.
  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];
      imports = [
        inputs.flake-parts.flakeModules.modules
        (inputs.import-tree ./modules)
        ./hosts
      ];
    };
}
