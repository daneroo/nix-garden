{ pkgs, lib, ... }:

let
  ghosttyConfig = pkgs.writeText "ghostty-config" ''
    keybind = super+c=copy_to_clipboard:mixed
    keybind = super+v=paste_from_clipboard
    keybind = super+t=new_tab
    keybind = super+w=close_tab:this
    keybind = super+shift+]=next_tab
    keybind = super+shift+[=previous_tab
    keybind = super+k=clear_screen
    keybind = super+n=new_window
    keybind = super+q=quit

    mouse-scroll-multiplier = precision:3,discrete:5
  '';
in
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
  users.groups.keyd = { };

  # Never suspend while charging; normal battery suspend behavior is
  # unchanged.
  programs.dconf.enable = true;
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/shell" = {
          favorite-apps = [
            "com.mitchellh.ghostty.desktop"
            "brave-browser.desktop"
            "org.gnome.Nautilus.desktop"
          ];
        };
        "org/gnome/shell/keybindings" = {
          toggle-message-tray = [ "<Super>m" ];
          focus-active-notification = lib.gvariant.mkEmptyArray "as";
          toggle-overview = lib.gvariant.mkEmptyArray "as";
        };
        "org/gnome/desktop/wm/keybindings" = {
          switch-input-source = [ "XF86Keyboard" ];
          switch-input-source-backward = [ "<Shift>XF86Keyboard" ];
        };
        "org/gnome/settings-daemon/plugins/media-keys" = {
          screensaver = [ "<Super><Shift>l" ];
          custom-keybindings = [
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
          ];
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          name = "Vicinae toggle";
          command = "${pkgs.vicinae}/bin/vicinae toggle";
          binding = "<Super>space";
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
          name = "1Password quick access";
          command = "1password --quick-access";
          binding = "<Super><Shift>space";
        };
        "org/gnome/desktop/peripherals/mouse" = {
          natural-scroll = true;
        };
        "org/gnome/settings-daemon/plugins/power" = {
          sleep-inactive-ac-type = "nothing";
          sleep-inactive-ac-timeout = lib.gvariant.mkInt32 0;
        };
      };
    }
  ];

  systemd.tmpfiles.rules = [
    "L+ /home/daniel/.config/ghostty/config - - - - ${ghosttyConfig}"
  ];

  environment.systemPackages = [ pkgs.vicinae ];

  systemd.user.services.vicinae = {
    description = "Vicinae launcher server";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.vicinae}/bin/vicinae server";
      Restart = "on-failure";
    };
  };

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
