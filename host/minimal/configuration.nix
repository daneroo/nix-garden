# see https://search.nixos.org/options
{
  modulesPath,
  config,
  lib,
  pkgs,
  hostName,
  diskDevice,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ../../disko/single-disk-ext4/disko-config.nix # Ensure the correct path
  ];

  # Enable QEMU for cross-architecture builds based on host platform
  boot.binfmt.emulatedSystems =
    if pkgs.stdenv.hostPlatform.isX86_64 then
      [ "aarch64-linux" ]
    else if pkgs.stdenv.hostPlatform.isAarch64 then
      [ "x86_64-linux" ]
    else
      [ ];

  # System settings passed as parameters
  networking.hostName = hostName; # Set hostname
  disko.devices.disk.main.device = diskDevice; # Set diskDevice

  # Nix specific settings
  nix.settings.experimental-features = "nix-command flakes";

  # TODO(daneroo): Let's circle back and understand our options here, but this works
  #  Wasn't able to boot with systemd-boot, so back to grub
  boot.loader = {
    grub.enable = false;
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true; # false for read-only firmware
  };

  # TODO(daneroo) regenerate in UTM for macnix
  # These are usually in hardware-configuration.nix
  # They were generateed from nixos-generate-config on proxmox
  # $ nixos-generate-config --show-hardware-config
  # Cannot write to /etc/nixos/ so generate in current directory and copy it out
  # Also our filesystems are handled by disko configs
  # $ nixos-generate-config --no-filesystems --dir .
  # boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  # boot.initrd.kernelModules = [ ];
  # boot.kernelModules = [ ];
  # boot.extraModulePackages = [ ];
  ####### ------- aarch64 / arm64 ------ #######
  ## FROM hardware-configuration-utm-arm64.nix
  # boot.initrd.availableKernelModules = [ "xhci_pci" "virtio_pci" "usbhid" "usb_storage" "sr_mod" ];
  # networking.useDHCP = lib.mkDefault true;
  # nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
  ####### ------- x86_64 / amd64 ------ #######
  ## FROM hardware-configuration-pxmx-amd64.nix
  # boot.initrd.availableKernelModules = [ "uhci_hcd" "ehci_pci" "ahci" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  # networking.useDHCP = lib.mkDefault true;
  # nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Enable networking
  networking.networkmanager.enable = true;
  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalization properties.
  # i18n.defaultLocale = "en_US.UTF-8";
  i18n.defaultLocale = "en_CA.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ALL = "en_CA.UTF-8";
  };

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable the OpenSSH server.
  services.openssh.enable = true;
  #services.openssh.settings.PermitRootLogin = "yes";

  # Enable the QEMU Guest Agent
  services.qemuGuest.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    curl
    jq
    htop
    emacs-nox
    git
    fastfetch
    btrfs-progs # CLI needed by switch-to-configuration
  ];

  users.users = {
    root = {
      # set a passwd with `mkpasswd -m sha-512`
      hashedPassword = "$6$K9VVOhEK7yygNC1T$PIirqGGbEqN6T4foCBTabahTNZfR.PDGqJUpzfAsHUxKs3vcSrv4my55.7nhgo6EQXeSgL025IjUQS.0AkIL80";
      # add an ssh authorized key
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrUdJY3Aj0Xi2zdlGrEHFv3FNnlMz6ASLclhhl9cj1p"
      ];
    };
    daniel = {
      isNormalUser = true;
      description = "daniel";
      extraGroups = [
        "networkmanager"
        "wheel"
      ];
      packages = with pkgs; [ ];
      # set a passwd with `mkpasswd -m sha-512`
      hashedPassword = "$6$K9VVOhEK7yygNC1T$PIirqGGbEqN6T4foCBTabahTNZfR.PDGqJUpzfAsHUxKs3vcSrv4my55.7nhgo6EQXeSgL025IjUQS.0AkIL80";
      # add an ssh authorized key
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrUdJY3Aj0Xi2zdlGrEHFv3FNnlMz6ASLclhhl9cj1p"
      ];
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. See https://nixos.org/nixos/options.html).
  system.stateVersion = "25.05";
}
