{ pkgs, lib, ... }:

let
  # Validated 2026-07-23 against a real Ghostty window; see
  # thoughts/tickets/keybinding-model.md for the per-binding test results.
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

    # Pre-existing issue (not caused by keybinding-model), fixed alongside it:
    # default multiplier for "precision" scroll devices is 1, producing an
    # unreadable one-line-at-a-time jump; bumped both categories up.
    mouse-scroll-multiplier = precision:3,discrete:5
  '';

  # keyd + keyd-application-mapper: the actual fix for Brave, since Chromium's
  # chrome.commands API hard-rejects Super/Meta as a shortcut modifier (no
  # policy or extension workaround exists -- confirmed against Chrome's own
  # ExtensionSettings docs). keyd remaps physical Alt<->Super below the
  # compositor (replacing the old xkb altwin:swap_alt_win, which this
  # subsumes); keyd-application-mapper retranslates Super+key into Brave's
  # native Ctrl+key ONLY while Brave has focus, via a patched GNOME Shell
  # extension (upstream only declares support for Shell 45-49; this system
  # runs 50.2 -- validated 2026-07-23: the extension's actual logic uses only
  # long-stable Shell APIs and ran correctly once the version string was
  # patched and keyd-application-mapper was made findable on PATH).
  # See thoughts/tickets/keybinding-model.md for the full validation trail.
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

  # Brave's own Linux defaults (Ctrl+T/W/N, Ctrl+Shift+T, Ctrl+Tab/Ctrl+Shift+Tab)
  # are the actual targets -- keyd-application-mapper rewrites our Super-based
  # chords into these only while a Brave window has focus. Window-class match
  # uses a bracket wildcard since Brave's exact WM_CLASS casing wasn't
  # empirically confirmed (attempted via the extension's own FIFO output, but
  # ran out of session time) -- verify and narrow once tested.
  keydAppConf = pkgs.writeText "keyd-app.conf" ''
    [[Bb]rave*]

    meta.t = C-t
    meta.w = C-w
    meta+shift.t = C-S-t
    meta.n = C-n
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

  # macOS-equivalence keybinding-model work (thoughts/tickets/keybinding-model.md).
  # Physical Alt key acts as the Cmd-equivalent Super modifier, matching
  # Daniel's existing macOS modifier swap; GNOME's own Super+V/Super+N
  # shortcuts are freed since they collided with Ghostty's paste/new-window
  # bindings before either reached the app.
  programs.dconf.enable = true;
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/shell" = {
          enabled-extensions = [ "keyd@keyd.rvaiya.github.com" ];
        };
        "org/gnome/shell/keybindings" = {
          toggle-message-tray = [ "<Super>m" ];
          focus-active-notification = lib.gvariant.mkEmptyArray "as";
          # Cmd+Space on macOS is the launcher-invoke reflex. GNOME's own
          # Activities overview was tried first here (zero-install baseline)
          # but Vicinae won the trial (MRU app search + inline calculator
          # confirmed working; Activities has neither) -- left unbound so it
          # doesn't collide with Vicinae's custom keybinding below.
          toggle-overview = lib.gvariant.mkEmptyArray "as";
        };
        "org/gnome/desktop/wm/keybindings" = {
          # <Super>space was switch-input-source by default, colliding with
          # the launcher-invoke binding above; kept the dedicated hardware
          # key (XF86Keyboard) so the function isn't lost, just the trigger.
          switch-input-source = [ "XF86Keyboard" ];
          switch-input-source-backward = [ "<Shift>XF86Keyboard" ];
        };
        "org/gnome/settings-daemon/plugins/media-keys" = {
          # Was <Super>l; freed for Brave's planned address-bar-focus binding
          # (Cmd+L on macOS) -- moved, not dropped, since lock-screen is a
          # function Daniel actually wants to keep.
          screensaver = [ "<Super><Shift>l" ];
          custom-keybindings = [
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
            "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
          ];
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
          # Launcher trial 2026-07-23: Vicinae won over Ulauncher (kept as a
          # lighter documented backup, see thoughts/tickets/keybinding-model.md)
          # and rofi (hard-requires the wlr-layer-shell protocol on Wayland,
          # same dead end as wofi/fuzzel/anyrun under Mutter). Confirmed
          # working: MRU-ordered app search, inline calculator ("Qalculate!"
          # backend). Known gaps: no date-math found in any candidate tried;
          # clipboard history needs Vicinae's own separate GNOME extension
          # (github.com/dagimg-dot/vicinae-gnome-extension, not yet pursued).
          name = "Vicinae toggle";
          command = "${pkgs.vicinae}/bin/vicinae toggle";
          binding = "<Super>space";
        };
        "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
          # Matches 1Password's own macOS default Quick Access shortcut
          # exactly (not just a Cmd-equivalence guess). Requires 1Password
          # already running (confirmed) -- the CLI flag reaches the existing
          # instance via its own single-instance IPC. Autofill into Brave
          # itself needs the 1Password browser extension, which arrives via
          # Daniel's existing Brave sync chain -- nothing to package here.
          name = "1Password quick access";
          command = "1password --quick-access";
          binding = "<Super><Shift>space";
        };
        "org/gnome/desktop/peripherals/mouse" = {
          # Pre-existing (not caused by keybinding-model work) but fixed
          # alongside it: matches Daniel's macOS-trained scroll expectation.
          natural-scroll = true;
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

  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        main = {
          # Cmd-equivalence base layer: physical Alt <-> Super, replacing the
          # old xkb altwin:swap_alt_win (keyd subsumes it). Symmetric on both
          # sides since the "us" layout here has no AltGr distinction to
          # preserve.
          leftalt = "layer(meta)";
          leftmeta = "layer(alt)";
          rightalt = "layer(meta)";
          rightmeta = "layer(alt)";
        };
        # Empty composite layer declaration -- required for
        # keyd-application-mapper's "meta+shift.<key>" bindings (next/prev
        # tab, reopen-closed-tab) to resolve at all. Confirmed via direct
        # `keyd bind` test: referencing an undeclared composite layer fails
        # outright ("meta+shift is not a valid layer"), silently passing the
        # raw Shift+key through instead of the intended shortcut -- this was
        # the cause of literal `{`/`}` characters typing into Brave's
        # address bar instead of switching tabs.
        "meta+shift" = { };
      };
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

  environment.systemPackages = [ pkgs.vicinae ];

  # No NixOS module ships for Vicinae (only a Home Manager one, which this
  # repo isn't adopting -- see feedback_defer_home_manager). "vicinae toggle"
  # (bound to Super+Space above) needs the server already running to have
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

  programs.firefox.enable = true;
  programs.git.enable = true;

  system.stateVersion = "26.05";
}
