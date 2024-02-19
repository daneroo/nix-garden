{
  description = "nix-garden exeperiments NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      proxmox = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
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
    nixosConfigurations.nix-full = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./nixos/configuration.nix
        ./nixos/hardware-configuration.nix
        # Any other modules you might have
      ];
    };
  };
}


