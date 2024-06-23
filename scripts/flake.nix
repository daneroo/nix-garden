{
  description = "NixOS Disko Format Install Script";

  inputs = { nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11"; };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in {
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          nixos-disko-format-install =
            pkgs.writeScriptBin "nixos-disko-format-install" {
              text = builtins.readFile ./nixos-disko-format-install.sh;
              runtimeInputs =
                [ pkgs.jq pkgs.gum ]; # Ensuring dependencies are included
            };
        });

      apps = forAllSystems (system: {
        nixos-disko-format-install = {
          type = "app";
          program = "${
              self.packages.${system}.nixos-disko-format-install
            }/bin/nixos-disko-format-install";
        };
      });
    };
}
