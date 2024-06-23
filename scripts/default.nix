{ stdenv, jq, gum, lib }:

stdenv.mkDerivation {
  pname = "nixos-disko-format-install";
  version = "1.0";  # Consider specifying a version

  src = ./nixos-disko-format-install.sh;

  buildInputs = [ jq gum ];  # Dependencies

# Directly specify the installation command in one line
  installPhase = "install -D -m0755 ${./nixos-disko-format-install.sh} $out/bin/nixos-disko-format-install";

  meta = {
    description = "A script to format disks with disko and install NixOS";
    license = lib.licenses.mit;  # Adjust the license as appropriate
  };
}
