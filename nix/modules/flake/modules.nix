# Adds the `flake.modules.<class>.<name>` option. Feature files register
# NixOS modules there, and hosts import them by name.
{ inputs, ... }:
{
  imports = [ inputs.flake-parts.flakeModules.modules ];
}
