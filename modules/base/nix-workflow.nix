# How this repository builds and identifies the systems it manages.
{ config, inputs, ... }:
{
  flake.modules.nixos.nix-workflow = {
    nix.settings.experimental-features = [
      "nix-command"
      "flakes"
    ];
    nixpkgs.config.allowUnfree = true;
    system.configurationRevision = inputs.self.rev or inputs.self.dirtyRev or "dirty";
    # `nh` finds the flake through NH_FLAKE from any directory; the canonical
    # managed-host checkout is fixed in docs/workflow.md. `just plan` and
    # `just apply` remain the authoritative lifecycle.
    programs.nh = {
      enable = true;
      flake = "/home/daniel/nix-garden";
    };
  };
  flake.modules.nixos.base.imports = [ config.flake.modules.nixos.nix-workflow ];
}
