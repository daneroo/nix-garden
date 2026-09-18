# The bootstrap tool set every host carries, desktop or not. Ghostty and Brave
# are installed here; their configuration lives in the desktop features.
{ config, inputs, ... }:
{
  flake.modules.nixos.cli-baseline =
    { pkgs, ... }:
    {
      # 1Password is not in this list: browser integration needs the
      # programs._1password-gui module with polkitPolicyOwners (see the
      # onepassword feature); a plain package would not build the required
      # wrapper.
      environment.systemPackages = with pkgs; [
        btop
        brave
        bun
        claude-code
        codex
        curl
        doggo
        dnsutils # dig
        fresh-editor
        gh
        ghostty
        git
        gum
        inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default
        just
        jq
        lazygit
        ripgrep
        vim
        wl-clipboard
      ];
      programs.git.enable = true;
    };
  flake.modules.nixos.base.imports = [ config.flake.modules.nixos.cli-baseline ];
}
