{
  description = "nix-garden experiments NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    # scripts.url = "path:./scripts";
    # scripts.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, ... }:
    let
      nixosSystems = [ "x86_64-linux" "aarch64-linux" ];

      nixosConfigSpecialArgs = {
        "x86_64-linux" = {
          diskDevice = "/dev/sda";
          hostName = "minimal-amd64";
        };
        "aarch64-linux" = {
          diskDevice = "/dev/vda";
          hostName = "minimal-arm64";
        };
      };

      makeNixosConfig = system:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = nixosConfigSpecialArgs.${system};
          modules =
            [ ./host/minimal/configuration.nix disko.nixosModules.disko ];
        };

      forAllNixOSSystems = nixpkgs.lib.genAttrs nixosSystems;

    in {
      nixosConfigurations = {
        minimal-amd64 = makeNixosConfig "x86_64-linux";
        minimal-arm64 = makeNixosConfig "aarch64-linux";
      };

    };
}
