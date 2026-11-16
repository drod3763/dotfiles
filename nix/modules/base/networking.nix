{ config, ... }:
let
  inherit (config.my) username;
in
{
  flake.modules.nixos.networking = {
    networking.networkmanager.enable = true;
    networking.firewall.enable = true;
    users.users.${username}.extraGroups = [ "networkmanager" ];
  };
}
