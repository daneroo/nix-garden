# 1Password desktop and CLI. The proper NixOS module rather than the plain
# package -- needed for the 1Password-BrowserSupport setgid wrapper that
# native-messaging-based browser extension integration actually requires.
# Confirmed missing (/run/wrappers/bin/1Password-BrowserSupport didn't exist)
# after joining Daniel's Brave sync chain, which installed the extension itself
# but had no working way to talk to the desktop app. See docs/keybindings.md
# and https://wiki.nixos.org/wiki/1Password.
#
# polkitPolicyOwners names Daniel directly; accepted for a single-user fleet.
{ config, ... }:
{
  flake.modules.nixos.onepassword = {
    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = [ "daniel" ];
    };
    programs._1password.enable = true;
  };
  flake.modules.nixos.desktop.imports = [ config.flake.modules.nixos.onepassword ];
}
