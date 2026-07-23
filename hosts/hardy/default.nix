{ pkgs, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "hardy";
  networking.domain = "imetrical.com";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "en_CA.UTF-8";

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.printing.enable = true;

  # The internal keyboard has distinct Ctrl, Alt, and Search keys; Search emits
  # left Meta. Physical Alt (beside Space, Daniel's Cmd position) becomes Meta,
  # Search becomes Alt/Option, and both physical Ctrl keys stay native. This
  # preserves all three roles without the per-app Ctrl compromise considered
  # before the hardware events were captured.
  #
  # The Chromebook top-row brightness keys arrive as plain F6/F7. ChromeOS's
  # keyboard-illumination convention is physical Alt+F6/F7, so those bindings
  # live in the resulting Meta layer and emit standard Linux illumination
  # events. Limit the entire mapping to the observed internal keyboard.
  services.keyd = {
    enable = true;
    keyboards.internal = {
      ids = [ "0001:0001:09b4e68d" ];
      settings = {
        main = {
          leftalt = "layer(meta)";
          rightalt = "layer(meta)";
          leftmeta = "layer(alt)";
        };
        meta = {
          f6 = "kbdillumdown";
          f7 = "kbdillumup";
        };
      };
    };
  };

  # Never suspend while charging; normal battery suspend behavior is
  # unchanged.
  programs.dconf.enable = true;
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/settings-daemon/plugins/power" = {
          sleep-inactive-ac-type = "nothing";
          sleep-inactive-ac-timeout = lib.gvariant.mkInt32 0;
        };
      };
    }
  ];

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.users.daniel = {
    isNormalUser = true;
    description = "Daniel Lauzon";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrUdJY3Aj0Xi2zdlGrEHFv3FNnlMz6ASLclhhl9cj1p daniel@galois"
    ];
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Temporary for agent-driven work on non-production hardy. Require passwords
  # again before this host carries important workloads.
  security.sudo.wheelNeedsPassword = false;

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  nixpkgs.config.allowUnfree = true;

  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "daniel" ];
  };
  programs._1password.enable = true;

  programs.git.enable = true;

  system.stateVersion = "26.05";
}
