{ pkgs, testers }:
{ hostModules, hostName, vmLayer }:
let
  # The behavioral suite is the Bun/TypeScript E2E under tests/e2e/bun -- the
  # same code that runs on the live session. The VM adds no behavioral logic; it
  # only launches that suite inside daniel's autologin GNOME session and reports
  # its exit. This flake filters the source path to git-tracked files, so the
  # gitignored node_modules (dev-only @types/bun) is excluded: `bun test` strips
  # types and the suite imports only `bun:test` plus its own local modules, so it
  # needs no runtime dependencies.
  bunSuite = ./e2e/bun;

  # A throwaway launcher, not a test. Python is only the nixos-test-driver's
  # required script language; every assertion lives in the Bun suite. Wait for
  # daniel's session the way the live suite's preconditions expect (compositor,
  # runtime dir, session bus, keyd, ydotoold), hand off into that session the
  # way the live wrapper does, and let `machine.succeed` propagate the suite's
  # merged output and exit status. `sudo -u daniel` reaches the session as root,
  # and daniel already has passwordless sudo (wheel + wheelNeedsPassword=false
  # from the host module), so the suite's own `sudo -n keyd monitor` works with
  # no VM-only grant.
  testScript = ''
    machine.wait_for_unit("graphical.target")
    machine.wait_until_succeeds("pgrep -u daniel gnome-shell")
    machine.wait_for_file("/run/user/1000/wayland-0")
    machine.wait_for_file("/run/user/1000/bus")
    machine.wait_for_unit("keyd.service")
    machine.wait_for_unit("ydotoold.service")

    print(
        machine.succeed(
            "sudo -u daniel env "
            "HOME=/home/daniel "
            "XDG_RUNTIME_DIR=/run/user/1000 "
            "WAYLAND_DISPLAY=wayland-0 "
            "XDG_SESSION_TYPE=wayland "
            "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus "
            "bash -lc 'cd ${bunSuite} && exec bun test --max-concurrency=1 ./*.test.ts' 2>&1",
            timeout=600,
        )
    )
  '';
in
testers.runNixOSTest {
  name = "desktop-${hostName}";
  inherit testScript;

  # Test the host configuration itself, not a reduced stand-in.
  node.pkgsReadOnly = false;
  nodes.machine = {
    imports = hostModules ++ [ vmLayer ];

    # brave, ghostty, and bun are imperative user installs on the real hosts
    # (no home-manager in this flake yet), so the VM closure lacks them. Provide
    # the apps under test and the runner. Everything else the Bun suite needs
    # (wl-clipboard via bootstrap packages, busctl, systemd-run, keyd, ydotool,
    # gnome-extensions) already comes from hostModules.
    environment.systemPackages = [
      pkgs.bun
      pkgs.ghostty
      pkgs.brave
    ];

    # Hardy's real keyd declaration intentionally matches only its internal
    # Chromebook keyboard. Give the VM's virtio keyboard an identity-preserving
    # config so ydotool injection still traverses keyd without weakening the
    # production device scope.
    services.keyd.keyboards.vm = pkgs.lib.mkIf (hostName == "hardy") {
      ids = [ "*" ];
      settings."alt+shift" = { };
    };

    services.gnome.at-spi2-core.enable = true;
    programs.dconf.profiles.user.databases = [
      {
        settings."org/gnome/desktop/interface".toolkit-accessibility = true;
      }
    ];
  };

  # The normal driver is headless. The interactive driver keeps the same launch
  # but opens QEMU's display so `just e2e-vm --show` can run observably -- the
  # context in which the display-dependent Brave and clipboard cases are meant
  # to be watched.
  interactive.nodes.machine.virtualisation.graphics = true;
}
