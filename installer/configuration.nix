# NixOS 25.05 Installer Configuration
# Uses the new installer framework with system.build.images
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    # Use the new image building modules instead of old cd-dvd approach
    (modulesPath + "/profiles/installation-device.nix")
  ];

  # Enable experimental Nix features
  nix.settings = {
    experimental-features = "nix-command flakes";
  };

  # Include NixOS 25.05 installer tools package
  environment.systemPackages = with pkgs; [
    wget
    curl
    htop
    emacs-nox
    git
    fastfetch
    jq
    gum
    # The new nixos-install-tools package from our research
    nixos-install-tools
  ];

  # Enable and configure SSH access
  systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];

  # SSH authorized keys for remote access
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrUdJY3Aj0Xi2zdlGrEHFv3FNnlMz6ASLclhhl9cj1p"
  ];
  users.users.nixos.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrUdJY3Aj0Xi2zdlGrEHFv3FNnlMz6ASLclhhl9cj1p"
  ];

  # Custom shell profile for IP display and connection instructions
  environment.etc."profile".text = ''
    # Check if the shell is interactive
    # [ -t 1 ]: True if file descriptor 1 is open and associated with a terminal
    if [ -t 1 ]; then
      fastfetch
      # Show IP address for SSH connection
      MYIP=$(ip -4 addr | grep -oP 'inet \K[\d.]+' | grep -v '^127\.0\.0\.1$')
      if [ -z "$MYIP" ]; then
        echo "IPv4 is not yet assigned; Just exit this shell to try again"
      else
        echo "Connect with SSH:"
        echo "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null nixos@$MYIP"
      fi
    fi
  '';

  # Image configuration for NixOS 25.05
  # Uses the new system.build.images approach
  # TODO: Find the correct way to configure ISO naming in the new framework
}
