# NixOS 25.05 Installer Configuration
#
# This configuration uses the NEW NixOS 25.05 installer framework built on system.build.images
# Key differences from legacy approach:
# - Uses image.modules.VARIANT to define image types
# - Provides system.build.images.VARIANT instead of system.build.isoImage
# - Build with: nix build .#nixosConfigurations.installer-x86_64.config.system.build.images.iso-installer
#
# NAMING: The new framework generates deterministic names like:
#   nixos-25.05.20250605.4792576-x86_64-linux.iso
# Custom naming via isoImage.isoName does NOT work within image.modules scope.
# The framework appears to override naming programmatically.
#
{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    # Installation device profile: provides installer environment (users, services, etc.)
    (modulesPath + "/profiles/installation-device.nix")
  ];

  # Enable experimental Nix features for flakes
  nix.settings = {
    experimental-features = "nix-command flakes";
  };

  # Essential packages for the installer environment
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

  # NixOS 25.05 Image Framework Configuration
  # Define the iso-installer variant that provides system.build.images.iso-installer
  image.modules.iso-installer = {
    imports = [ (modulesPath + "/installer/cd-dvd/iso-image.nix") ];

    # ISO configuration
    isoImage.makeEfiBootable = true;
    isoImage.makeUsbBootable = true;

    # NOTE: Custom naming doesn't work - framework overrides isoImage.isoName
    # Results in: nixos-25.05.20250605.4792576-x86_64-linux.iso (deterministic and good)
  };
}
