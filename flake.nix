{
  description = "Reproducible system config for the homelab fleet";

  inputs = {
    herdr.url = "github:ogulcancelik/herdr/v0.7.5";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      herdr,
      nixpkgs,
      ...
    }:
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
        herdr.packages.${system}.default
        just
        jq
        lazygit
        vim
      ];
      hosts = [
        "hardy"
        "gauss"
      ];
      hostModules =
        name:
        [
          (./hosts + "/${name}")
          # Inert in a normal system/test build; used by `nixos-rebuild
          # build-vm`.
          ./modules/vm-variant.nix
          {
            environment.systemPackages = bootstrapPackages;
            # Stamp the building commit into the system so a host can report
            # which revision of this repository it is running. Without it
            # `nixos-rebuild list-generations` shows "Unknown". A dirty tree
            # stamps as such, which is itself useful signal.
            system.configurationRevision = self.rev or self.dirtyRev or "dirty";
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
      mkHost =
        name:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = hostModules name;
        };
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs hosts mkHost;

      # Deliberately not under `checks`. `nix flake check` -- and so
      # `just check` -- BUILDS everything under `checks` but only EVALUATES
      # `packages`. Living here means each test is type-checked and evaluated on
      # every commit, catching a broken test expression early, without booting a
      # GNOME session in the pre-commit gate. Run them with `just e2e-vm`.
      packages.${system} =
        let
          testLib = pkgs.callPackage ./tests/lib.nix { inherit pkgs; };

          desktopTest = testLib {
            hostModules = hostModules "gauss";
            vmLayer = ./modules/vm-layer.nix;
          };
        in
        {
          test-desktop = desktopTest;

          # Renders the JUnit artifacts a run leaves behind. Provided by the
          # flake rather than installed on the hosts: this is a repository tool,
          # and gauss has no python3 on PATH.
          test-report = pkgs.writeShellApplication {
            name = "test-report";
            runtimeInputs = [ pkgs.python3 ];
            text = ''python3 ${./scripts/e2e-test-report.py} "$@"'';
          };
        };
    };
}
