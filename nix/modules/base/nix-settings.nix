{ config, ... }:
let
  inherit (config.my) username;
in
{
  flake.modules.nixos.nix-settings = {
    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      trusted-users = [
        "root"
        username
      ];
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    # NVIDIA, Steam, 1Password and others are unfree.
    nixpkgs.config.allowUnfree = true;
  };
}
