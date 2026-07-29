{ lib, pkgs, ... }:

let
  ydotoolSocket = "/run/ydotoold/socket";

  ydotoolDaemon = pkgs.writeShellScript "nix-garden-ydotoold" ''
    exec ${pkgs.ydotool}/bin/ydotoold \
      --socket-path=${ydotoolSocket} \
      --socket-perm=0600 \
      --mouse-off
  '';

in
{
  # Only the service receives uinput as a supplementary group; Daniel gets its
  # mode-0600 datagram socket, not general /dev/uinput access. The test
  # therefore injects before keyd without sudo or a new login-time membership.
  programs.ydotool = {
    enable = true;
    group = "users";
  };
  systemd.services.ydotoold = {
    before = [ "keyd.service" ];
    serviceConfig = {
      ExecStart = lib.mkForce ydotoolDaemon;
      User = lib.mkForce "daniel";
      Group = lib.mkForce "users";
      SupplementaryGroups = lib.mkAfter [ "uinput" ];
      PrivateUsers = lib.mkForce false;
      RuntimeDirectoryMode = lib.mkForce "0700";
    };
  };

  environment.variables.YDOTOOL_SOCKET = lib.mkForce ydotoolSocket;
}
