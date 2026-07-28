{ pkgs, ... }:

let
  paperwmToggleCommand = pkgs.writeShellApplication {
    name = "paperwm-toggle";
    runtimeInputs = [
      pkgs.gnome-shell
      pkgs.gnugrep
    ];
    text = ''
      # @vicinae.schemaVersion 1
      # @vicinae.title Toggle PaperWM Tiling
      # @vicinae.mode silent

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
        gnome-extensions list --enabled | grep -Fxq "$uuid" ||
          fail "extension still reports disabled after enable"
        state="enabled"
      fi

      printf 'PaperWM tiling %s\n' "$state"
    '';
  };

  # Vicinae searches XDG data directories rather than PATH for script commands.
  # Keep both entry points in one system-owned package so removing the package
  # removes its shell and launcher surfaces together.
  paperwmToggle = pkgs.runCommand "paperwm-toggle-with-vicinae" { } ''
    mkdir -p "$out/bin" "$out/share/vicinae/scripts"
    ln -s ${paperwmToggleCommand}/bin/paperwm-toggle \
      "$out/bin/paperwm-toggle"
    ln -s "$out/bin/paperwm-toggle" \
      "$out/share/vicinae/scripts/paperwm-toggle"
  '';
in
{
  environment.systemPackages = [
    pkgs.gnomeExtensions.paperwm
    paperwmToggle
  ];
}
