# Ghostty's keybindings, the terminal side of docs/keybindings.md. The package
# is in cli-baseline.
{ config, ... }:
{
  flake.modules.nixos.ghostty =
    { pkgs, ... }:
    let
      # The default multiplier for "precision" scroll devices is 1, producing
      # an unreadable one-line-at-a-time jump; both categories are bumped up.
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
    in
    {
      # Stopgap; the XDG parents are owned by user-daniel, which explains why
      # every parent must be declared explicitly.
      systemd.tmpfiles.rules = [
        "d /home/daniel/.config/ghostty 0755 daniel users -"
        "L+ /home/daniel/.config/ghostty/config - - - - ${ghosttyConfig}"
      ];
    };
  flake.modules.nixos.desktop.imports = [ config.flake.modules.nixos.ghostty ];
}
