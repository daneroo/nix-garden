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

    # Pre-existing issue (not caused by keybinding-model), fixed alongside it:
    # default multiplier for "precision" scroll devices is 1, producing an
    # unreadable one-line-at-a-time jump; bumped both categories up.
    mouse-scroll-multiplier = precision:3,discrete:5
  '';

  paperwmToggle = pkgs.writeShellApplication {
    name = "paperwm-toggle";
    runtimeInputs = [
      pkgs.gnome-shell
      pkgs.gnugrep
    ];
    text = ''
      # @vicinae.schemaVersion 1
      # @vicinae.title Toggle PaperWM Tiling
      # @vicinae.mode silent

      # System-wide is a compromise while nix-garden does not manage Daniel's
      # user scripts. A user-scoped command would be the natural home.
      uuid="paperwm@paperwm.github.com"

      fail() { printf 'PaperWM tiling: %s\n' "$1"; exit 1; }

      command -v gnome-extensions >/dev/null 2>&1 ||
        fail "gnome-extensions is unavailable"

      gnome-extensions info "$uuid" >/dev/null 2>&1 ||
        fail "extension is unavailable in this GNOME session"

      if gnome-extensions list --enabled | grep -Fxq "$uuid"; then
        gnome-extensions disable "$uuid" || fail "could not disable the extension"
        ! gnome-extensions list --enabled | grep -Fxq "$uuid" ||
          fail "extension still reports enabled after disable"
        state="disabled"
      else
        gnome-extensions enable "$uuid" || fail "could not enable the extension"
        gnome-extensions list --active | grep -Fxq "$uuid" ||
          fail "extension enabled but did not become active"
        state="enabled"
      fi

      printf 'PaperWM tiling %s\n' "$state"
    '';
  };

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

  networking.hostName = "gauss";
  networking.domain = "imetrical.com";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "en_CA.UTF-8";

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

  # Stopgap. This whole block is what `home-config-ownership` in the backlog
  # exists to delete, and the fix below grew it rather than shrinking it —
  # keep that trade deliberate rather than letting the list creep further.
  #
  # Every parent directory below is declared explicitly, and must stay that way.
  # systemd-tmpfiles refuses to descend a path whose ownership changes -- a
  # symlink-attack guard -- and materialising a parent implicitly creates it as
  # root. On a home that already contains daniel-owned .config and .local the
  # rules work by luck; on a fresh one tmpfiles creates a root-owned .config,
  # then its own guard makes it skip every L+ beneath, silently and without
  # failing the unit. Found 2026-07-25 in the test-harness VM, where none of
  # these three dotfiles existed: "Detected unsafe path transition
  # /home/daniel (owned by daniel) -> /home/daniel/.config (owned by root)".
  # A reinstall of this host would have hit the same thing.
  #
  # Modes match what the running system already had, so applying this changes
  # no existing permissions: XDG wants 0700 on .config and .local/share.
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

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      # keyd-application-mapper cannot dynamically bind a composite layer
      # unless the static config declares it first. No base modifier mapping:
      # Alt, Ctrl, both Windows-logo keys, and right Alt/AltGr stay native.
      settings."alt+shift" = { };
    };
  };

  # keyd-application-mapper needs to be resolvable via PATH by whatever
  # spawns it (the GNOME Shell extension); adding it here (rather than only
  # via the keyd systemd service's own ExecStart) makes it findable through
  # the per-user profile, which existing long-running processes' PATH
  # entries already include -- unlike a brand-new PATH entry, this doesn't
  # require a fresh login to take effect.
  users.users.daniel.packages = [ pkgs.keyd ];

  systemd.services.keyd.serviceConfig = {
    # Upstream's docs assume a dedicated "keyd" group (usermod -aG keyd);
    # the NixOS module doesn't create one. Using "users" instead -- daniel's
    # existing primary group -- means socket access works without daniel
    # needing a fresh login to pick up new group membership.
    Group = lib.mkForce "users";
    UMask = lib.mkForce "0007";
  };

  environment.systemPackages = [
    pkgs.gnomeExtensions.paperwm
    pkgs.vicinae
    paperwmToggle
  ];

  # No NixOS module ships for Vicinae (only a Home Manager one, which this
  # repo isn't adopting -- see feedback_defer_home_manager). "vicinae toggle"
  # (bound to Alt+Space above) needs the server already running to have
  # anything to toggle.
  systemd.user.services.vicinae = {
    description = "Vicinae launcher server";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.vicinae}/bin/vicinae server";
      Restart = "on-failure";
    };
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
    isNormalUser = true;
    description = "Daniel Lauzon";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBrUdJY3Aj0Xi2zdlGrEHFv3FNnlMz6ASLclhhl9cj1p daniel@galois"
    ];
    # Keeps user services (e.g. Herdr's server) running independent of an
    # active login session -- set imperatively via `loginctl enable-linger`
    # during keybinding-model work to survive a GNOME logout/login cycle
    # needed to refresh Shell's app-grid file watchers; encoded here so it
    # isn't lost on a future reinstall.
    linger = true;
  };

  # Proper NixOS module instead of the plain package (which was in the
  # shared flake.nix bootstrapPackages until now) -- needed for the
  # 1Password-BrowserSupport setgid wrapper that native-messaging-based
  # browser extension integration actually requires. Confirmed missing
  # (/run/wrappers/bin/1Password-BrowserSupport didn't exist) after joining
  # Daniel's Brave sync chain, which installed the extension itself but had
  # no working way to talk to the desktop app. See docs/keybindings.md and
  # https://wiki.nixos.org/wiki/1Password.
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "daniel" ];
  };
  programs._1password.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      KbdInteractiveAuthentication = false;
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Temporary for agent-driven work on non-production gauss. Require passwords
  # again before this host carries important workloads.
  security.sudo.wheelNeedsPassword = false;

  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  nixpkgs.config.allowUnfree = true;

  programs.git.enable = true;

  system.stateVersion = "26.05";
}
