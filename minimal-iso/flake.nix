{
  description = "Minimal NixOS installation media";
  # See https://nixos.wiki/wiki/Creating_a_NixOS_live_CD
  # inputs.nixos.url = "nixpkgs/23.11-beta";
  inputs.nixos.url = "nixpkgs/23.11";
  outputs = { self, nixos }: {
    nixosConfigurations = {
      exampleIso = nixos.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixos}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ({ pkgs, ... }: {
              environment.systemPackages = with pkgs; [
                wget
                curl
                htop
                emacs-nox
                git
              ];

          })
        ];
      };
    };
  };
}