{
  description = "Minimal NixOS installation media";
  # See https://nixos.wiki/wiki/Creating_a_NixOS_live_CD
  # inputs.nixos.url = "nixpkgs/23.11-beta";
  inputs.nixos.url = "nixpkgs/23.11";
  outputs = { self, nixos }: {
    nixosConfigurations = {
      exampleIso = nixos.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          "${nixos}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
          ({ pkgs, ... }: {
              environment.systemPackages = with pkgs; [
                wget
                curl
                htop
                emacs-nox
                git
                fastfetch
              ];
              # Enable SSH in the boot process.
              systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];
              users.users.root.openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrUdJY3Aj0Xi2zdlGrEHFv3FNnlMz6ASLclhhl9cj1p"
              ];
              users.users.nixos.openssh.authorizedKeys.keys = [
                "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrUdJY3Aj0Xi2zdlGrEHFv3FNnlMz6ASLclhhl9cj1p"
              ];
              environment.etc."profile".text = ''
                # show my ip!
                fastfetch
              '';
          })
        ];
      };
    };
  };
}