{ pkgs, lib, ... }:

let
  # keyd ships a GNOME extension only for Shell 45-49. Gauss runs Shell 50.2;
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

  networking.hostName = "gauss";

  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  # gnome-console (GTK "Terminal") is confusable with Ghostty, the actual
  # target terminal for keybinding-model work; drop it from the default set.
  environment.gnome.excludePackages = [ pkgs.gnome-console ];
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.printing.enable = true;

  programs.dconf.enable = true;
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/shell" = {
          # GNOME hides Log Out for a single local user with a single session
          # type, which both hosts now are: GNOME 50 dropped the Xorg session,
          # so `sessionData.desktops` holds only `gnome.desktop`. Hardy has
          # carried this key since 38cdb98; gauss never had it, which is why
          # the menu differed between them rather than any regression.
          always-show-log-out = true;
          enabled-extensions = [
            "keyd@keyd.rvaiya.github.com"
            "paperwm@paperwm.github.com"
          ];
          # Pinned to the dash 2026-07-23; Files (Nautilus) was already
          # there as a GNOME default, kept alongside Ghostty and Brave.
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
          # Launcher trial 2026-07-23: Vicinae won over Ulauncher (kept as a
          # lighter documented backup, see docs/keybindings.md)
          # and rofi (hard-requires the wlr-layer-shell protocol on Wayland,
          # same dead end as wofi/fuzzel/anyrun under Mutter). Confirmed
          # working: MRU-ordered app search, inline calculator ("Qalculate!"
          # backend). Known gaps: no date-math found in any candidate tried;
          # clipboard history needs Vicinae's own separate GNOME extension
          # (github.com/dagimg-dot/vicinae-gnome-extension, not yet pursued).
          name = "Vicinae toggle";
          command = "${pkgs.vicinae}/bin/vicinae toggle";
          binding = "<Alt>space";
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
          # Preserve Daniel's physical Alt+Shift+Space Quick Access chord.
          # Requires 1Password already running (confirmed) -- the CLI flag
          # reaches the existing instance via its own single-instance IPC.
          # Autofill into Brave itself needs the 1Password browser extension,
          # which arrives via Daniel's existing Brave sync chain -- nothing to
          # package here.
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
          # Pre-existing (not caused by keybinding-model work) but fixed
          # alongside it: matches Daniel's macOS-trained scroll expectation.
          natural-scroll = true;
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

  services.keyd = {
    keyboards.default = {
      ids = [ "*" ];
      # keyd-application-mapper cannot dynamically bind a composite layer
      # unless the static config declares it first. No base modifier mapping:
      # Alt, Ctrl, both Windows-logo keys, and right Alt/AltGr stay native.
      settings."alt+shift" = { };
    };
  };

  systemd.services.keyd.serviceConfig = {
    # Upstream's docs assume a dedicated "keyd" group (usermod -aG keyd);
    # the NixOS module doesn't create one. Using "users" instead -- daniel's
    # existing primary group -- means socket access works without daniel
    # needing a fresh login to pick up new group membership.
    Group = lib.mkForce "users";
  };

  # gauss is an always-on homelab box, not a laptop; never suspend.
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  users.users.daniel = {
    # Keeps user services (e.g. Herdr's server) running independent of an
    # active login session -- set imperatively via `loginctl enable-linger`
    # during keybinding-model work to survive a GNOME logout/login cycle
    # needed to refresh Shell's app-grid file watchers; encoded here so it
    # isn't lost on a future reinstall.
    linger = true;
  };

  system.stateVersion = "26.05";
}
