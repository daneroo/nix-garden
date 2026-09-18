# The GNOME side of docs/keybindings.md: shell and window-manager chords, the
# screensaver chords, and the custom commands bound to Vicinae, 1Password, and
# logout.
{ config, ... }:
{
  flake.modules.nixos.gnome-keybindings =
    { lib, pkgs, ... }:
    {
      programs.dconf.profiles.user.databases = [
        {
          settings = {
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
              activate-window-menu = lib.gvariant.mkEmptyArray lib.gvariant.type.string;
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
          };
        }
      ];
    };
  flake.modules.nixos.gnome.imports = [ config.flake.modules.nixos.gnome-keybindings ];
}
