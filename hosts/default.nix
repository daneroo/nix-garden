# The machine inventory: which hosts exist and how each one is composed.
# `nixosConfigurations` is defined here and nowhere else.
{
  config,
  inputs,
  lib,
  ...
}:
let
  hosts = [
    "hardy"
    "gauss"
  ];

  nixos = config.flake.modules.nixos;

  # The shared block formerly inlined in flake.nix, moved verbatim. It dissolves
  # into features in the next stage.
  inlineShared =
    { pkgs, ... }:
    {
      # 1Password lives in each host's programs._1password-gui module because
      # browser integration needs a per-host polkitPolicyOwners override; a
      # plain package in this shared list would not build the required wrapper.
      environment.systemPackages = with pkgs; [
        btop
        brave
        bun
        claude-code
        codex
        curl
        doggo
        dnsutils # dig
        fresh-editor
        gh
        ghostty
        git
        gum
        inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
        just
        jq
        lazygit
        ripgrep
        vim
        wl-clipboard
      ];
      system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or "dirty";
      # Bound the boot menu and let a failed generation fall back on its
      # own; see docs/workspace.md. Retention is by recency, not by
      # known-good -- the generation-gc ticket owns that and store space.
      boot.loader.systemd-boot = {
        configurationLimit = 20;
        bootCounting.enable = true;
      };
      programs.nh = {
        enable = true;
        flake = "/home/daniel/nix-garden";
      };
      services.tailscale.enable = true;
      xdg.mime.defaultApplications = {
        "text/html" = "brave-browser.desktop";
        "x-scheme-handler/http" = "brave-browser.desktop";
        "x-scheme-handler/https" = "brave-browser.desktop";
        "x-scheme-handler/about" = "brave-browser.desktop";
        "x-scheme-handler/unknown" = "brave-browser.desktop";
      };
    };
in
{
  flake.modules.nixos = lib.genAttrs' hosts (name: {
    name = "host-${name}";
    value = {
      imports = [
        (./. + "/${name}")
        nixos.e2e-injection
        nixos.paperwm
        # Inert in a normal system/test build; used by `nixos-rebuild
        # build-vm`.
        nixos.vm-variant
        inlineShared
      ];
    };
  });

  flake.nixosConfigurations = lib.genAttrs hosts (
    name:
    inputs.nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [ nixos."host-${name}" ];
    }
  );
}
