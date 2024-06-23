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

      forAllSystems = nixpkgs.lib.genAttrs nixosSystems;

    in {
      nixosConfigurations = {
        minimal-amd64 = makeNixosConfig "x86_64-linux";
        minimal-arm64 = makeNixosConfig "aarch64-linux";
      };

      # packages = {
      #   x86_64-linux.nixos-disko-format-install =
      #     nixpkgs.legacyPackages.x86_64-linux.callPackage ./scripts/default.nix
      #     { };
      #   aarch64-linux.nixos-disko-format-install =
      #     nixpkgs.legacyPackages.aarch64-linux.callPackage ./scripts/default.nix
      #     { };
      # };
      apps = forAllSystems (system: {
        nixos-disko-format-install = {
          type = "app";
          program = nixpkgs.legacyPackages.${system}.writeShellApplication {
            name = "nixos-disko-format-install";
            runtimeInputs = with nixpkgs.legacyPackages.${system}; [ jq gum ];
            text = builtins.readFile ./scripts/nixos-disko-format-install.sh;
          };
        };
      });
    };
}
