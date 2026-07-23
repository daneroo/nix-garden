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
        "org/gnome/desktop/input-sources" = {
          xkb-options = [ "altwin:swap_alt_win" ];
        };
        "org/gnome/shell/keybindings" = {
          toggle-message-tray = [ "<Super>m" ];
          focus-active-notification = lib.gvariant.mkEmptyArray "as";
        };
      };
    }
  ];

  systemd.tmpfiles.rules = [
    "L+ /home/daniel/.config/ghostty/config - - - - ${ghosttyConfig}"
  ];

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
