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
      # 1Password lives in each host's programs._1password-gui module because
      # browser integration needs a per-host polkitPolicyOwners override; a
      # plain package in this shared list would not build the required wrapper.
      bootstrapPackages = with pkgs; [
        brave
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
              services.tailscale.enable = true;
              xdg.mime.defaultApplications = {
                "text/html" = "brave-browser.desktop";
                "x-scheme-handler/http" = "brave-browser.desktop";
                "x-scheme-handler/https" = "brave-browser.desktop";
                "x-scheme-handler/about" = "brave-browser.desktop";
                "x-scheme-handler/unknown" = "brave-browser.desktop";
              };
            }
          ];
        };
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs hosts mkHost;
    };
}
