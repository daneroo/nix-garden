{
  description = "nix-garden experiments NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, ... }: {
    nixosConfigurations = {
      minimal-x86_64 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = {
          diskDevice = "/dev/sda"; # Provide the disk device as parameter
          hostName = "x86_64-minimal"; # Provide the hostname as parameter
        };
        modules = [ ./host/minimal/configuration.nix disko.nixosModules.disko ];
      };
      minimal-aarch64 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {
          diskDevice = "/dev/vda"; # Provide the disk device as parameter
          hostName = "aarch64-minimal"; # Provide the hostname as parameter
        };
        modules = [ ./host/minimal/configuration.nix disko.nixosModules.disko ];
      };
    };
  };
}
