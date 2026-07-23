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

  # Brave has no native Super bindings. Translate only while Brave has focus,
  # preserving native Ctrl globally and closing the macOS-equivalence gaps that
  # Chromium's chrome.commands API cannot accept.
  keydAppConf = pkgs.writeText "keyd-app.conf" ''
    [brave-browser]

    meta.c = C-c
    meta.v = C-v
    meta.t = C-t
    meta.w = C-w
    meta+shift.t = C-S-t
    meta+shift.w = C-S-w
    meta.n = C-n
    meta.l = C-l
    meta.f = C-f
    meta+shift.rightbrace = C-tab
    meta+shift.leftbrace = C-S-tab
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
        # keyd-application-mapper cannot dynamically bind a composite layer
        # unless the static config declares it first.
        "meta+shift" = { };
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
          toggle-message-tray = [ "<Super>m" ];
          focus-active-notification = lib.gvariant.mkEmptyArray "as";
          toggle-overview = lib.gvariant.mkEmptyArray "as";
          screenshot = [
            "<Shift>Print"
            "<Super><Shift>3"
          ];
          screenshot-window = [ "<Alt>Print" ];
          show-screenshot-ui = [
            "Print"
            "<Super><Shift>4"
          ];
        };
        "org/gnome/desktop/wm/keybindings" = {
          switch-input-source = [ "XF86Keyboard" ];
          switch-input-source-backward = [ "<Shift>XF86Keyboard" ];
        };
        "org/gnome/settings-daemon/plugins/media-keys" = {
          screensaver = [
            "<Super><Shift>l"
            "<Control><Super>q"
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
          binding = "<Super>space";
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
          name = "1Password quick access";
          command = "1password --quick-access";
          binding = "<Super><Shift>space";
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2" = {
          name = "Log out";
          command = "${pkgs.gnome-session}/bin/gnome-session-quit --logout";
          binding = "<Super><Shift>q";
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
    "d /home/daniel/.local/share/gnome-shell/extensions 0755 daniel users -"
    "L+ /home/daniel/.local/share/gnome-shell/extensions/keyd@keyd.rvaiya.github.com - - - - ${keydGnomeExtension}"
    "d /home/daniel/.config/keyd 0755 daniel users -"
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
