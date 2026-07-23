{
  description = "Reproducible system config for the homelab fleet";

  inputs = {
    herdr.url = "github:ogulcancelik/herdr/v0.7.5";
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
        claude-code
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
      hosts = [
        "hardy"
        "gauss"
      ];
      mkHost =
        name:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            (./hosts + "/${name}")
            {
              environment.systemPackages = bootstrapPackages;
            }
          ];
        };
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs hosts mkHost;
    };
}
