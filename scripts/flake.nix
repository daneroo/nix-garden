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
          default = pkgs.symlinkJoin {
            name = "nixos-disko-format-install";
            paths = [
              (pkgs.writeShellScriptBin "nixos-disko-format-install"
                (builtins.readFile ./nixos-disko-format-install.sh))
            ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/nixos-disko-format-install \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.jq pkgs.gum ]}
            '';
          };
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program =
            "${self.packages.${system}.default}/bin/nixos-disko-format-install";
        };
      });
    };
}
