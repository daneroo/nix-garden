{
  description = "nix-garden exeperiments NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko }: {
    nixosConfigurations = {
      proxmox = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./host/proxmox/configuration.nix
        ];
      };
    };
    nixosConfigurations.post = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./post-install/configuration.nix
        ./post-install/hardware-configuration.nix
        # Any other modules you might have
      ];
    };
  };
}


