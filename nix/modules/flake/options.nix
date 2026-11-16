# Values shared by every feature module. Read them from the flake-parts
# `config` in the outer function, not from the NixOS `config`.
{ lib, ... }:
{
  options.my = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "derick";
      description = "Primary login user on every host.";
    };
    fullName = lib.mkOption {
      type = lib.types.str;
      default = "Derick Rodriguez";
    };
  };
}
