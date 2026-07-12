{
  description = "Reproducible system config for hardy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    { nixpkgs, ... }:
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
