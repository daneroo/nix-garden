# What a host's configuration needs in order to be testable in a VM, and
# nothing else. This is a plain module rather than a `virtualisation.vmVariant`
# block because two different drive modes need it and only one of them merges
# vmVariant: `nixos-rebuild build-vm` does, `runNixOSTest` does not. Keeping the
# layer here lets `vm-variant.nix` hand it to build-vm and the checks hand
# it to the test driver, from one definition.
#
# Importing this into a real host configuration would be a mistake -- it grants
# passwordless graphical login. Nothing does; see vm-variant.nix for how
# the build-vm path keeps it off real machines.
{ lib, pkgs, ... }:
{
  # A fresh VM disk carries no /etc/shadow entries, so every account is locked
  # -- observed 2026-07-25: GDM offers a bare username field and both `root`
  # and `daniel` are refused on the serial getty. Neither host sets a password
  # declaratively (their passwords were set imperatively with `passwd`), so
  # autologin is what makes the VM reach a session at all.
  services.displayManager.autoLogin = {
    enable = true;
    user = "daniel";
  };

  # A test VM must open on the desktop it is testing, not a first-login
  # assistant. GNOME Shell launches Tour when its desktop file is present on a
  # user's first login; excluding it is both narrower and more reliable than
  # trying to dismiss its window after the session starts.
  environment.gnome.excludePackages = [ pkgs.gnome-tour ];
  services.gnome.gnome-initial-setup.enable = false;

  # The VM password is literally `secret`, and that is written here on purpose.
  # It is a test fixture, not a secret: never reuse it and never replace it with
  # a real password. Keeping an opaque hash here previously hid a public value
  # from the person trying to operate the fixture, which locked the driver out
  # twice on 2026-07-25. A known credential lets an unattended run log in on the
  # serial console or clear a lock screen.
  #
  # Nothing is weakened by publishing it. The VM's sshd keeps
  # `PasswordAuthentication = false` from the host configuration, so this opens
  # no network path, and the disk is discarded between runs.
  #
  # This is `password`, not `initialPassword`: `e2e-vm --no-test` intentionally
  # reuses a qcow2 disk, so an initial value would not update an account created
  # by an earlier run. Reasserting the fixture value on every VM activation
  # keeps the persistent exploration VM and disposable test VMs consistent.
  users.users.daniel.password = "secret";

  # Never blank on idle: an unattended assertion that pauses long enough for the
  # screensaver loses its session to a password prompt.
  #
  # Only the idle trigger is disabled. `lock-enabled` is deliberately left alone
  # so that locking on demand still behaves as it does on a real host -- the
  # lock-screen check asserts exactly that chord, and turning it off here would
  # have quietly made that test assert nothing.
  programs.dconf.profiles.user.databases = [
    {
      settings = {
        "org/gnome/desktop/session".idle-delay = lib.gvariant.mkUint32 0;
      };
    }
  ];

  # The runner defaults -- 1 GB and a single core -- are far too thin for a
  # GNOME session. gauss has 16 cores and 27 GB, so this is generous without
  # being noticeable on the host.
  virtualisation.memorySize = 4096;
  virtualisation.cores = 4;
}
