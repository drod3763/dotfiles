# Apps that need system services or setuid helpers, so they can't be plain
# packages from the manifest bridge (Phase 2).
{ config, ... }:
let
  inherit (config.my) username;
in
{
  flake.modules.nixos.app-services = {
    programs._1password.enable = true;
    programs._1password-gui = {
      enable = true;
      # Lets the CLI and browser extensions unlock through the desktop app.
      polkitPolicyOwners = [ username ];
    };

    programs.steam.enable = true;

    services.tailscale.enable = true;

    virtualisation.docker.enable = true;
    users.users.${username}.extraGroups = [ "docker" ];
  };
}
