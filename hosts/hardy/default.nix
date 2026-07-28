{ pkgs, lib, ... }:

let
  ghosttyConfig = pkgs.writeText "ghostty-config" ''
    keybind = alt+c=copy_to_clipboard:mixed
    keybind = alt+v=paste_from_clipboard
    keybind = alt+t=new_tab
    keybind = alt+w=close_tab:this
    keybind = alt+shift+]=next_tab
    keybind = alt+shift+[=previous_tab
    keybind = alt+k=clear_screen
    keybind = alt+n=new_window
    keybind = alt+q=quit

    mouse-scroll-multiplier = precision:3,discrete:5
  '';

  # keyd ships a GNOME extension only for Shell 45-49. Hardy runs Shell 50.2;
  # the extension uses stable APIs, so extend only its declared compatibility.
  keydGnomeExtensionPatcher = pkgs.writeText "patch-keyd-metadata.py" ''
    import json, sys
    src, dst = sys.argv[1], sys.argv[2]
    with open(src) as f:
        m = json.load(f)
    if "50" not in m["shell-version"]:
        m["shell-version"].append("50")
    with open(dst, "w") as f:
        json.dump(m, f, indent=2)
  '';

  keydGnomeExtension = pkgs.runCommand "keyd-gnome-extension-patched" { } ''
    mkdir -p $out
    cp ${pkgs.keyd}/share/keyd/gnome-extension-45/extension.js $out/
    ${pkgs.python3}/bin/python3 ${keydGnomeExtensionPatcher} \
      ${pkgs.keyd}/share/keyd/gnome-extension-45/metadata.json \
      $out/metadata.json
  '';

  # Brave uses Ctrl for these actions. Translate native Alt only while Brave
  # has focus, preserving native Alt and Ctrl everywhere else.
  keydAppConf = pkgs.writeText "keyd-app.conf" ''
    [brave-browser]

    alt.c = C-c
    alt.v = C-v
    alt.t = C-t
    alt.w = C-w
    alt+shift.t = C-S-t
    alt.n = C-n
    alt.l = C-l
    alt.f = C-f
    alt+shift.rightbrace = C-tab
    alt+shift.leftbrace = C-S-tab
    # Alt+L is translated above, so preserve GNOME's overlapping lock chord.
    alt+shift.l = A-S-l
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
  # Linux Super. Keep all three native and use this device-specific declaration
  # only for its Chromebook keyboard-illumination chord.
  #
  # The Chromebook top-row brightness keys arrive as plain F6/F7. ChromeOS's
  # keyboard-illumination convention is physical Alt+F6/F7. Emit the standard
  # Linux illumination events only for the observed internal keyboard.
  services.keyd = {
    enable = true;
    keyboards.internal = {
      ids = [ "0001:0001:09b4e68d" ];
      settings = {
        alt = {
          f6 = "kbdillumdown";
          f7 = "kbdillumup";
        };
        # keyd-application-mapper cannot dynamically bind a composite layer
        # unless the static config declares it first.
        "alt+shift" = { };
      };
    };
  };

  # keyd drops its effective group to "keyd" when that group exists. The NixOS
  # unit's capability bounding set omits CAP_SETGID by default, so adding the
  # group alone makes the daemon fail. Grant only that missing capability and
  # use a group-readable socket; do not expose it to Gauss's broad "users"
  # group. Daniel receives the new membership at the required logout below.
  users.groups.keyd = { };
  systemd.services.keyd.serviceConfig = {
    CapabilityBoundingSet = lib.mkAfter [ "CAP_SETGID" ];
    UMask = lib.mkForce "0007";
  };

  # Never suspend while charging; normal battery suspend behavior is
  # unchanged.
  programs.dconf.enable = true;
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/shell" = {
          always-show-log-out = true;
          enabled-extensions = [ "keyd@keyd.rvaiya.github.com" ];
          favorite-apps = [
            "com.mitchellh.ghostty.desktop"
            "brave-browser.desktop"
            "org.gnome.Nautilus.desktop"
          ];
        };
        "org/gnome/shell/keybindings" = {
          screenshot = [
            "<Shift>Print"
            "<Alt><Shift>3"
          ];
          screenshot-window = [ "<Alt>Print" ];
          show-screenshot-ui = [
            "Print"
            "<Alt><Shift>4"
          ];
        };
        "org/gnome/desktop/wm/keybindings" = {
          # Vicinae owns native Alt+Space. Super+Space and the dedicated
          # keyboard key return to GNOME's stock input-source behavior.
          activate-window-menu =
            lib.gvariant.mkEmptyArray lib.gvariant.type.string;
        };
        "org/gnome/settings-daemon/plugins/media-keys" = {
          screensaver = [
            "<Alt><Shift>l"
            "<Super>l"
            "<Control><Alt>q"
          ];
          custom-keybindings = [
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/"
          ];
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          name = "Vicinae toggle";
          command = "${pkgs.vicinae}/bin/vicinae toggle";
          binding = "<Alt>space";
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
          name = "1Password quick access";
          command = "1password --quick-access";
          binding = "<Alt><Shift>space";
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
          name = "Log out";
          command = "${pkgs.gnome-session}/bin/gnome-session-quit --logout";
          binding = "<Alt><Shift>q";
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

  # Stopgap, like gauss's: `home-config-ownership` in the backlog replaces this
  # block wholesale with a user-owned mechanism.
  #
  # Parent directories are declared explicitly for the reason documented in
  # hosts/gauss/default.nix: systemd-tmpfiles will not descend a daniel -> root
  # ownership transition, and an implicitly materialised parent is root-owned,
  # so on a fresh home every L+ below is skipped without the unit failing.
  # Keep the two hosts in step; the failure is silent on a reinstall.
  systemd.tmpfiles.rules = [
    "d /home/daniel/.config 0700 daniel users -"
    "d /home/daniel/.config/ghostty 0755 daniel users -"
    "d /home/daniel/.config/keyd 0755 daniel users -"
    "d /home/daniel/.local 0755 daniel users -"
    "d /home/daniel/.local/share 0700 daniel users -"
    "d /home/daniel/.local/share/gnome-shell 0700 daniel users -"
    "d /home/daniel/.local/share/gnome-shell/extensions 0755 daniel users -"
    "L+ /home/daniel/.config/ghostty/config - - - - ${ghosttyConfig}"
    "L+ /home/daniel/.local/share/gnome-shell/extensions/keyd@keyd.rvaiya.github.com - - - - ${keydGnomeExtension}"
    "L+ /home/daniel/.config/keyd/app.conf - - - - ${keydAppConf}"
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
      "keyd"
      "networkmanager"
      "wheel"
    ];
    packages = [ pkgs.keyd ];
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
