# see https://search.nixos.org/options
{ modulesPath, config, lib, pkgs, hostName, diskDevice, ... }: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    (modulesPath + "/profiles/qemu-guest.nix")
    ../../disko/single-disk-ext4/disko-config.nix # Ensure the correct path
  ];

  # System settings passed as parameters
  networking.hostName = hostName; # Set hostname
  disko.devices.disk.main.device = diskDevice; # Set diskDevice

  # Nix specific settings
  nix.settings.experimental-features = "nix-command flakes";

  # TODO(daneroo): Let's circle back and understand our options here, but this works
  boot.loader.grub = {
    efiSupport = true;
    efiInstallAsRemovable = true;
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
  };

  # TODO(daneroo) regenerate in UTM for macnix
  # These are usually in hardware-configuration.nix
  # They were generateed from nixos-generate-config on proxmox
  # boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  # boot.initrd.kernelModules = [ ];
  # boot.kernelModules = [ ];
  # boot.extraModulePackages = [ ];

  # Enable networking
  networking.networkmanager.enable = true;
  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  # What is this for?
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };
  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Enable the OpenSSH server.
  services.openssh.enable = true;
  # Enable the QEMU Guest Agent
  services.qemuGuest.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    #  vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    curl
    htop
    emacs-nox
    git
    fastfetch

  ];

  users.users = {
    root = {
      # set a passwd with `mkpasswd -m sha-512`
      hashedPassword =
        "$6$K9VVOhEK7yygNC1T$PIirqGGbEqN6T4foCBTabahTNZfR.PDGqJUpzfAsHUxKs3vcSrv4my55.7nhgo6EQXeSgL025IjUQS.0AkIL80";
      # add an ssh authorized key
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrUdJY3Aj0Xi2zdlGrEHFv3FNnlMz6ASLclhhl9cj1p"
      ];
    };
    daniel = {
      isNormalUser = true;
      description = "daniel";
      extraGroups = [ "networkmanager" "wheel" ];
      packages = with pkgs; [ ];
      # set a passwd with `mkpasswd -m sha-512`
      hashedPassword =
        "$6$K9VVOhEK7yygNC1T$PIirqGGbEqN6T4foCBTabahTNZfR.PDGqJUpzfAsHUxKs3vcSrv4my55.7nhgo6EQXeSgL025IjUQS.0AkIL80";
      # add an ssh authorized key
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrUdJY3Aj0Xi2zdlGrEHFv3FNnlMz6ASLclhhl9cj1p"
      ];
    };
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. See https://nixos.org/nixos/options.html).
  system.stateVersion = "23.11";
}
