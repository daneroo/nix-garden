# hardy: ASUS Chromebook Flip C436F, the first managed host. Hardware, the
# three aspects, identity, and the exceptions below; everything else is a
# feature under modules/.
{ config, ... }:
{
  flake.modules.nixos.host-hardy =
    { lib, ... }:
    {
      imports = [
        ./hardware-configuration.nix
        config.flake.modules.nixos.base
        config.flake.modules.nixos.desktop
        config.flake.modules.nixos.gnome
      ];

      networking.hostName = "hardy";
      system.stateVersion = "26.05";

      # The internal keyboard has distinct Ctrl, Alt, and Search keys; Search
      # emits Linux Super. Keep all three native and use this device-specific
      # declaration only for its Chromebook keyboard-illumination chord.
      #
      # The Chromebook top-row brightness keys arrive as plain F6/F7. ChromeOS's
      # keyboard-illumination convention is physical Alt+F6/F7. Emit the
      # standard Linux illumination events only for the observed internal
      # keyboard.
      services.keyd.keyboards.internal = {
        # The desktop E2E harness injects physical chords through ydotool's
        # virtual keyboard (2333:6666). keyd must manage that device so injected
        # chords traverse the real keyd path; gauss gets this via `[ids] *`, but
        # hardy deliberately scopes to the internal keyboard, so the injection
        # device is listed explicitly. It harmlessly inherits the internal
        # remaps.
        ids = [
          "0001:0001:09b4e68d"
          "2333:6666"
        ];
        settings = {
          alt = {
            f6 = "kbdillumdown";
            f7 = "kbdillumup";
          };
          # keyd-application-mapper cannot dynamically bind a composite layer
          # unless the static config declares it first.
          "alt+shift" = { };
        };
      };

      # keyd drops its effective group to "keyd" when that group exists. The
      # NixOS unit's capability bounding set omits CAP_SETGID by default, so
      # adding the group alone makes the daemon fail. Grant only that missing
      # capability and use a group-readable socket; do not expose it to Gauss's
      # broad "users" group. Daniel receives the new membership at the required
      # logout below.
      users.groups.keyd = { };
      systemd.services.keyd.serviceConfig.CapabilityBoundingSet = lib.mkAfter [ "CAP_SETGID" ];
      users.users.daniel.extraGroups = [ "keyd" ];

      # A laptop: never suspend while charging; normal battery suspend behavior
      # is unchanged.
      programs.dconf.profiles.user.databases = [
        {
          settings = {
            "org/gnome/settings-daemon/plugins/power" = {
              sleep-inactive-ac-type = "nothing";
              sleep-inactive-ac-timeout = lib.gvariant.mkInt32 0;
            };
          };
        }
      ];
    };
}
