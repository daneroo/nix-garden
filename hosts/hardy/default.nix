{ pkgs, lib, ... }:

let
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

in
{
  imports = [
    ./hardware-configuration.nix
  ];

  networking.hostName = "hardy";

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
    keyboards.internal = {
      # The desktop E2E harness injects physical chords through ydotool's
      # virtual keyboard (2333:6666). keyd must manage that device so injected
      # chords traverse the real keyd path; gauss gets this via `[ids] *`, but
      # hardy deliberately scopes to the internal keyboard, so the injection
      # device is listed explicitly. It harmlessly inherits the internal remaps.
      ids = [
        "0001:0001:09b4e68d"
        "2333:6666"
      ];
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
  };

  # Never suspend while charging; normal battery suspend behavior is
  # unchanged.
  programs.dconf.enable = true;
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/shell" = {
          always-show-log-out = true;
          enabled-extensions = [
            "keyd@keyd.rvaiya.github.com"
            "paperwm@paperwm.github.com"
          ];
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
        "org/gnome/shell/extensions/paperwm" = {
          winprops = [
            (builtins.toJSON {
              wm_class = "vicinae";
              scratch_layer = true;
            })
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

  # Stopgap; the XDG parents are owned by the user-daniel feature, which also
  # explains why every parent must be declared explicitly.
  systemd.tmpfiles.rules = [
    "d /home/daniel/.local/share/gnome-shell 0700 daniel users -"
    "d /home/daniel/.local/share/gnome-shell/extensions 0755 daniel users -"
    "L+ /home/daniel/.local/share/gnome-shell/extensions/keyd@keyd.rvaiya.github.com - - - - ${keydGnomeExtension}"
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
    # Socket access to keyd via the dedicated group declared above.
    extraGroups = [ "keyd" ];
  };

  system.stateVersion = "26.05";
}
