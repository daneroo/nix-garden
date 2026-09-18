# keyd's GNOME Shell extension, which reports the focused window so
# keyd-application-mapper can apply the Brave map. gnome-session enables it by
# UUID.
{ config, ... }:
{
  flake.modules.nixos.keyd-gnome-extension =
    { pkgs, ... }:
    let
      # keyd ships a GNOME extension only for Shell 45-49. Both hosts run
      # Shell 50; the extension uses stable APIs, so extend only its declared
      # compatibility.
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
      # Stopgap; the XDG parents are owned by user-daniel, which explains why
      # every parent must be declared explicitly.
      systemd.tmpfiles.rules = [
        "d /home/daniel/.local/share/gnome-shell 0700 daniel users -"
        "d /home/daniel/.local/share/gnome-shell/extensions 0755 daniel users -"
        "L+ /home/daniel/.local/share/gnome-shell/extensions/keyd@keyd.rvaiya.github.com - - - - ${keydGnomeExtension}"
      ];
    };
  flake.modules.nixos.gnome.imports = [ config.flake.modules.nixos.keyd-gnome-extension ];
}
