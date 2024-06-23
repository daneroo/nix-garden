{
  description = "nix-garden experiments NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
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
      # this works but has system as key... I prefer my own names as above
      # nixosConfigurations = forAllNixOSSystems (system: {
      #   ${nixosConfigSpecialArgs.${system}.hostName} = makeNixosConfig system;
      # });

      packages = forAllNixOSSystems (system: {
        nixos-disko-format-install =
          nixpkgs.legacyPackages.${system}.callPackage ./scripts/default.nix
          { };
      });

      apps = forAllNixOSSystems (system: {
        nixos-disko-format-install = {
          type = "app";
          program = "${
              self.packages.${system}.nixos-disko-format-install
            }/bin/nixos-disko-format-install";
        };
      });

    };
}
