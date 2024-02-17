{
  description = "nix-garden exeperiments NixOS flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.nix-full = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./nixos/configuration.nix
        ./nixos/hardware-configuration.nix
        # Any other modules you might have
      ];
    };
  };
}


