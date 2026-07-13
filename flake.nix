{
  description = "Reproducible system config for hardy";

  inputs = {
    herdr.url = "github:ogulcancelik/herdr/v0.7.3";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { herdr, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      bootstrapPackages = with pkgs; [
        _1password-gui
        bun
        codex
        curl
        fresh-editor
        gh
        ghostty
        git
        herdr.packages.${system}.default
        just
        jq
        btop
        vim
      ];
    in
    {
      nixosConfigurations.hardy = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/hardy
          {
            environment.systemPackages = bootstrapPackages;
          }
        ];
      };
    };
}
