{
  description = "nix-garden experiments NixOS flake";

  inputs = {
    # flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, flake-utils, ... }:
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
    in {
      # for some reason, flake-utils.lib.eachSystem nixosSystems is not working here
      nixosConfigurations = {
        minimal-amd64 = makeNixosConfig "x86_64-linux";
        minimal-arm64 = makeNixosConfig "aarch64-linux";
      };

      packages = {
        x86_64-linux.nixos-disko-format-install =
          nixpkgs.legacyPackages.x86_64-linux.callPackage ./scripts/default.nix
          { };
        aarch64-linux.nixos-disko-format-install =
          nixpkgs.legacyPackages.aarch64-linux.callPackage ./scripts/default.nix
          { };
      };
      apps = {
        x86_64-linux.nixos-disko-format-install = {
          type = "app";
          program =
            "${self.packages.x86_64-linux.nixos-disko-format-install}/bin/nixos-disko-format-install";
        };
        aarch64-linux.nixos-disko-format-install = {
          type = "app";
          program =
            "${self.packages.aarch64-linux.nixos-disko-format-install}/bin/nixos-disko-format-install";
        };
      };
    };
}
