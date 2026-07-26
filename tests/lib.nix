{ pkgs, testers }:
{ hostModules, vmLayer }:
let
  dogtailPython = pkgs.python3.withPackages (python: [ python.dogtail ]);
  typelibPath = pkgs.lib.makeSearchPath "lib/girepository-1.0" [
    pkgs.glib.out
    pkgs.gobject-introspection
    pkgs.gdk-pixbuf
    pkgs.librsvg
    pkgs.at-spi2-core
    pkgs.gsettings-desktop-schemas
    pkgs.harfbuzz
    pkgs.pango.out
    pkgs.gtk3
  ];

  # This is a terminal-protocol peer, not a shell. Each Ghostty surface claims
  # a monotonic identity through the standard OSC 0 title protocol, then
  # acknowledges bytes received through its PTY by changing that title. The
  # test can therefore observe tab selection, window focus, and paste without
  # scraping pixels, depending on a shell prompt, or guessing process trees.
  ghosttyFixture = pkgs.writeShellScript "nix-garden-ghostty-fixture" ''
    counter=/run/user/1000/nix-garden-ghostty-surface-counter
    exec 9>"$counter.lock"
    ${pkgs.util-linux}/bin/flock 9
    current=0
    if [ -r "$counter" ]; then
      read -r current < "$counter"
    fi
    current=$((current + 1))
    printf '%s\n' "$current" > "$counter"
    ${pkgs.util-linux}/bin/flock -u 9
    role="surface-$current"

    ${pkgs.coreutils}/bin/stty -echo

    set_title() {
      printf '\033]0;%s\007' "$1"
    }

    printf 'COPY_PROBE'
    set_title "nix-garden-test-$role"

    while IFS= read -r line; do
      case "$line" in
        FOCUS)
          set_title "nix-garden-test-$role-focused"
          ;;
        WINDOW_FOCUS)
          set_title "nix-garden-test-$role-window-focused"
          ;;
        *)
          set_title "nix-garden-test-paste-$role-$line"
          ;;
      esac
    done
  '';

  ghosttyConfig = pkgs.writeText "nix-garden-ghostty-config" ''
    # The normal user config remains loaded. These settings replace only the
    # child process and nondeterministic confirmation policies needed by this
    # test; the Super bindings under test still come from gauss itself.
    initial-command = direct:${ghosttyFixture}
    command = direct:${ghosttyFixture}
    shell-integration = none
    confirm-close-surface = false
    clipboard-read = allow
    clipboard-write = allow
    clipboard-paste-protection = false
    copy-on-select = false
    window-show-tab-bar = always
    gtk-single-instance = false
  '';

  # Ghostty's terminal renderer is a custom widget, so AT-SPI does not expose
  # terminal cells or tabs. GTK does expose each top-level frame and its exact
  # terminal-supplied title. Comparing the complete sorted title set gives us a
  # stable semantic assertion for windows and the selected tab. The
  # nix-garden-test prefix belongs only to the fixture, so unrelated accessible
  # applications cannot be mistaken for Ghostty.
  ghosttyFrames = pkgs.writeText "nix-garden-ghostty-frames.py" ''
    import sys
    from dogtail import tree

    expected = sorted(sys.argv[1:])
    actual = sorted(
        frame.name
        for application in tree.root.children
        for frame in application.children
        if frame.roleName == "frame"
        and frame.name.startswith("nix-garden-test-")
    )
    assert actual == expected, (
        f"expected Ghostty frames {expected!r}, got {actual!r}"
    )
  '';

  ghosttyFrameProbe = pkgs.writeShellScriptBin "ghostty-frame-probe" ''
    export GI_TYPELIB_PATH=${typelibPath}
    exec ${dogtailPython}/bin/python3 ${ghosttyFrames} "$@"
  '';
in
testers.runNixOSTest {
  name = "desktop";
  testScript = builtins.readFile ./lib.py + "\n" + builtins.readFile ./desktop.py;

  # Test the host configuration itself, not a reduced stand-in.
  node.pkgsReadOnly = false;
  nodes.machine = {
    imports = hostModules ++ [ vmLayer ];
    environment.systemPackages = [
      pkgs.wl-clipboard
      ghosttyFrameProbe
    ];
    environment.etc."nix-garden/ghostty-test-config".source = ghosttyConfig;
    services.gnome.at-spi2-core.enable = true;
    programs.dconf.profiles.user.databases = [
      {
        settings."org/gnome/desktop/interface".toolkit-accessibility = true;
      }
    ];
  };

  # The normal driver is headless. The interactive driver keeps the same test
  # script but opens QEMU's display so `just e2e-vm --show` can run observably.
  interactive.nodes.machine.virtualisation.graphics = true;
}
