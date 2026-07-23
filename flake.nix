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
      # 1Password moved to hosts/gauss/default.nix's programs._1password-gui
      # (needs a per-host polkitPolicyOwners override for browser-extension
      # integration, which builds a different package than this shared list
      # would produce) -- see thoughts/tickets/keybinding-model.md. hardy
      # loses it here until it gets the same module treatment during backport.
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
