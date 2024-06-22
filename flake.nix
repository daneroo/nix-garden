{
  description = "nix-garden experiments NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, ... }: {
    nixosConfigurations = {
      minimal-amd64 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          diskDevice = "/dev/sda"; # Provide the disk device as parameter
          hostName = "minimal-amd64"; # Provide the hostname as parameter
        };
        modules = [ ./host/minimal/configuration.nix disko.nixosModules.disko ];
      };
      minimal-arm64 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {
          diskDevice = "/dev/vda"; # Provide the disk device as parameter
          hostName = "minimal-arm64"; # Provide the hostname as parameter
        };
        modules = [ ./host/minimal/configuration.nix disko.nixosModules.disko ];
      };
    };
  };
}
