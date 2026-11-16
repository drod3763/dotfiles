{ config, ... }:
let
  inherit (config.my) username fullName;
in
{
  flake.modules.nixos.users =
    { pkgs, ... }:
    {
      programs.zsh.enable = true;

      # chezmoi manages the dotfiles; Nix only creates the account.
      # The installer sets the password with `nixos-enter -c "passwd <user>"`.
      users.users.${username} = {
        isNormalUser = true;
        description = fullName;
        shell = pkgs.zsh;
        extraGroups = [
          "wheel"
          "video"
        ];
      };

      environment.systemPackages = with pkgs; [
        chezmoi
        git
      ];
    };
}
