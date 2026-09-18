# The desktop VM suites and their report tool. This directory is the E2E
# harness: unlike the aspect directories, nothing here registers into an
# aspect, and vm-layer must never reach a real host.
{
  config,
  inputs,
  lib,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    {
      # flake-parts defaults `pkgs` to nixpkgs' legacyPackages, which has no
      # `allowUnfree`; the test tooling may be unfree, as it always could.
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Deliberately not under `checks`. `nix flake check` -- and so
      # `just check` -- BUILDS everything under `checks` but only EVALUATES
      # `packages`. Living here means each test is type-checked and evaluated on
      # every commit, catching a broken test expression early, without booting a
      # GNOME session in the pre-commit gate. Run them with `just e2e-vm`.
      packages =
        let
          testLib = pkgs.callPackage ../../tests/lib.nix { inherit pkgs; };

          desktopTests = lib.genAttrs (builtins.attrNames config.flake.nixosConfigurations) (
            hostName:
            testLib {
              inherit hostName;
              hostModules = [ config.flake.modules.nixos."host-${hostName}" ];
              vmLayer = config.flake.modules.nixos.vm-layer;
            }
          );
        in
        {
          # Keep the original output as a compatibility alias while the public
          # recipe selects a host-specific instance.
          test-desktop = desktopTests.gauss;
          test-desktop-hardy = desktopTests.hardy;
          test-desktop-gauss = desktopTests.gauss;

          # Renders the JUnit artifacts a run leaves behind. Provided by the
          # flake rather than installed on the hosts: this is a repository tool,
          # and gauss has no python3 on PATH.
          test-report = pkgs.writeShellApplication {
            name = "test-report";
            runtimeInputs = [ pkgs.python3 ];
            text = ''python3 ${../../scripts/e2e-test-report.py} "$@"'';
          };
        };
    };
}
