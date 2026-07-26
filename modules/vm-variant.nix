# Hands the shared VM testability layer to `nixos-rebuild build-vm`.
#
# `virtualisation.vmVariant` is merged only when building a VM, so nothing in
# [vm-layer.nix](vm-layer.nix) can reach a real machine through this path:
# `just plan` and `just apply` evaluate the same configuration without it.
# Verified by evaluation rather than assumed -- on `.#gauss`,
# `services.displayManager.autoLogin.enable` is `false`,
# `users.users.daniel.password` is `null`, and
# `virtualisation.memorySize` is not even a defined option.
#
# The checks import `vm-layer.nix` directly instead, because `runNixOSTest`
# does not merge `vmVariant`. See docs/e2e-testing.md.
{ ... }:
{
  virtualisation.vmVariant = {
    imports = [ ./vm-layer.nix ];
  };
}
