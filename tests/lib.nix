{ pkgs, testers }:
{ hostModules, hostName, vmLayer }:
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

    ${pkgs.coreutils}/bin/stty -echo -isig

    set_title() {
      printf '\033]0;%s\007' "$1"
    }

    printf 'COPY_PROBE'
    set_title "nix-garden-test-$role"

    while IFS= read -r line; do
      case "$line" in
        $'\003')
          set_title "nix-garden-test-control-c-$role"
          ;;
        $'\033d')
          set_title "nix-garden-test-alt-d-$role"
          ;;
        FOCUS)
          set_title "nix-garden-test-$role-focused"
          ;;
        POPULATE)
          printf '\nclear-screen line 1\nclear-screen line 2\n'
          set_title "nix-garden-test-populated-$role"
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
    # test; the production bindings under test still come from the selected
    # host itself.
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

  bravePageOne = pkgs.writeText "one.html" ''
    <!doctype html>
    <html>
      <head>
        <title>Nix Garden Brave One</title>
      </head>
      <body>
        <textarea id="target" autofocus>COPY_PROBE</textarea>
        <script>
          const target = document.getElementById("target");
          target.focus();
          target.select();
          target.addEventListener("input", () => {
            document.title = `Nix Garden Brave One ''${target.value}`;
          });
        </script>
      </body>
    </html>
  '';

  bravePageTwo = pkgs.writeText "two.html" ''
    <!doctype html>
    <html>
      <head>
        <title>Nix Garden Brave Two</title>
      </head>
      <body>
        <p>FIND_NEEDLE</p>
      </body>
    </html>
  '';

  braveFixture = pkgs.runCommand "nix-garden-brave-fixture" { } ''
    mkdir -p "$out"
    cp ${bravePageOne} "$out/one.html"
    cp ${bravePageTwo} "$out/two.html"
  '';

  # Chromium exposes its top-level frames through AT-SPI when renderer
  # accessibility is enabled. Frame count distinguishes a new window from a
  # new tab; the active frame title identifies the selected local fixture tab.
  braveFrames = pkgs.writeText "nix-garden-brave-frames.py" ''
    import sys
    from dogtail import tree

    expected_count = int(sys.argv[1])
    expected_title = sys.argv[2] if len(sys.argv) > 2 else None
    frames = [
        frame
        for application in tree.root.children
        if "brave" in application.name.lower()
        for frame in application.children
        if frame.roleName == "frame"
    ]
    names = sorted(frame.name for frame in frames)
    assert len(frames) == expected_count, (
        f"expected {expected_count} Brave frames, got {names!r}"
    )
    if expected_title is not None:
        assert any(expected_title in name for name in names), (
            f"expected a Brave frame containing {expected_title!r}, got {names!r}"
        )
  '';

  braveFrameProbe = pkgs.writeShellScriptBin "brave-frame-probe" ''
    export GI_TYPELIB_PATH=${typelibPath}
    exec ${dogtailPython}/bin/python3 ${braveFrames} "$@"
  '';

  # Record the logical modifiers delivered with a neutral key press. QEMU
  # injects the physical chord; GTK/GDK observes the compositor-facing result.
  modifierProbeScript = pkgs.writeText "nix-garden-modifier-probe.py" ''
    import sys
    from pathlib import Path
    from gi.repository import Gdk, Gtk

    result_path = Path(sys.argv[1])
    window = Gtk.Window(title="nix-garden-modifier-probe")
    window.set_default_size(320, 120)

    def focused(_window, _event):
        result_path.write_text("FOCUSED")

    def mapped(_window, _event):
        if not result_path.exists():
            result_path.write_text("MAPPED")

    def pressed(_window, event):
        if Gdk.keyval_name(event.keyval).lower() != "x":
            return False
        masks = [
            ("CTRL", Gdk.ModifierType.CONTROL_MASK),
            ("ALT", Gdk.ModifierType.MOD1_MASK),
            ("SUPER", Gdk.ModifierType.SUPER_MASK),
            ("META", Gdk.ModifierType.META_MASK),
            ("HYPER", Gdk.ModifierType.HYPER_MASK),
            ("MOD4", Gdk.ModifierType.MOD4_MASK),
        ]
        active = [name for name, mask in masks if event.state & mask]
        result_path.write_text("+".join(active) if active else "NONE")
        Gtk.main_quit()
        return True

    window.connect("focus-in-event", focused)
    window.connect("map-event", mapped)
    window.connect("key-press-event", pressed)
    window.connect("destroy", Gtk.main_quit)
    window.show_all()
    window.present()
    Gtk.main()
  '';

  modifierProbe = pkgs.writeShellScriptBin "modifier-probe" ''
    export GI_TYPELIB_PATH=${typelibPath}
    exec ${dogtailPython}/bin/python3 ${modifierProbeScript} "$@"
  '';
in
testers.runNixOSTest {
  name = "desktop-${hostName}";
  testScript = builtins.readFile ./lib.py + "\n" + builtins.readFile ./desktop.py;

  # Test the host configuration itself, not a reduced stand-in.
  node.pkgsReadOnly = false;
  nodes.machine = {
    imports = hostModules ++ [ vmLayer ];
    environment.systemPackages = [
      pkgs.darkhttpd
      pkgs.wl-clipboard
      braveFrameProbe
      ghosttyFrameProbe
      modifierProbe
    ];
    # Hardy's real keyd declaration intentionally matches only its internal
    # Chromebook keyboard. Give the VM's virtio keyboard an identity-preserving
    # config so the focused Brave mapper can still be exercised without
    # weakening the production device scope.
    services.keyd.keyboards.vm = pkgs.lib.mkIf (hostName == "hardy") {
      ids = [ "*" ];
      settings."alt+shift" = { };
    };
    environment.etc."nix-garden/brave-fixture".source = braveFixture;
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
