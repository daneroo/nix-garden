{ stdenv, jq, gum, lib }:

stdenv.mkDerivation {
  pname = "nixos-disko-format-install";
  version = "1.0"; # Consider specifying a version

  src = ./nixos-disko-format-install.sh;

  # Prevent Nix from trying to unpack the script
  dontUnpack = true;

  # Directly specify the installation command
  installPhase = ''
    mkdir -p $out/bin
    cp ${./nixos-disko-format-install.sh} $out/bin/nixos-disko-format-install
    chmod +x $out/bin/nixos-disko-format-install
  '';

  meta = {
    description = "A script to format disks with disko and install NixOS";
    license = lib.licenses.mit; # Adjust the license as appropriate
  };
}
