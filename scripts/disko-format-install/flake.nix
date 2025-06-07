{
  description = "NixOS Disko Format Install Script";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
  };

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.symlinkJoin {
            name = "disko-format-install";
            paths = [
              (pkgs.writeShellScriptBin "disko-format-install" (builtins.readFile ./disko-format-install.sh))
            ];
            buildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/disko-format-install \
                --prefix PATH : ${
                  pkgs.lib.makeBinPath [
                    pkgs.jq
                    pkgs.gum
                  ]
                }
            '';
          };
        }
      );

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/disko-format-install";
        };
      });
    };
}
