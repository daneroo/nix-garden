{
  description = "My Customized Minimal NixOS installation media";

  # Proven Repeatable on 2024-11-15
  inputs.nixos.url = "nixpkgs/24.05";

  outputs =
    { self, nixos }:
    let

      commonConfiguration =
        system:
        nixos.lib.nixosSystem {
          inherit system;
          modules = [
            "${nixos}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
            (
              { pkgs, ... }:
              {
                # Enable experimental features
                nix.settings = {
                  experimental-features = "nix-command flakes";
                };

                # System packages
                environment.systemPackages = with pkgs; [
                  wget
                  curl
                  htop
                  emacs-nox
                  git
                  fastfetch
                ];

                # Enable and configure SSH
                systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];
                services.openssh.settings.PermitRootLogin = "yes";

                users.users.root.openssh.authorizedKeys.keys = [
                  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrUdJY3Aj0Xi2zdlGrEHFv3FNnlMz6ASLclhhl9cj1p"
                ];
                users.users.nixos.openssh.authorizedKeys.keys = [
                  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrUdJY3Aj0Xi2zdlGrEHFv3FNnlMz6ASLclhhl9cj1p"
                ];

                # Custom /etc/profile
                environment.etc."profile".text = ''
                  fastfetch
                  # show my ip!
                  MYIP=$(ip -4 addr | grep -oP 'inet \K[\d.]+' | grep -v '^127\.0\.0\.1$')
                  if [ -z "$MYIP" ]; then
                    echo "IPv4 is not yet assigned; Just exit this shell to try again"
                  else
                    echo "Connect with SSH:"
                    echo "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null nixos@$MYIP"
                  fi
                '';
              }
            )
          ];
        };

    in
    {
      nixosConfigurations = {
        x86_64Iso = commonConfiguration "x86_64-linux";
        aarch64Iso = commonConfiguration "aarch64-linux";
      };
    };
}
