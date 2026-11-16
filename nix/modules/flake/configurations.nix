# Each `configurations.nixos.<name>.module` becomes
# `nixosConfigurations.<name>`, and its system closure becomes a check on its
# platform so `nix flake check` builds it.
{ lib
, config
, inputs
, ...
}:
{
  options.configurations.nixos = lib.mkOption {
    type = lib.types.lazyAttrsOf (
      lib.types.submodule {
        options.module = lib.mkOption {
          type = lib.types.deferredModule;
          description = "The host's top-level NixOS module.";
        };
      }
    );
    default = { };
  };

  config.flake = {
    nixosConfigurations = lib.mapAttrs
      (
        _name: { module }: inputs.nixpkgs.lib.nixosSystem { modules = [ module ]; }
      )
      config.configurations.nixos;

    checks = lib.mkMerge (
      lib.mapAttrsToList
        (
          name: nixos: {
            ${nixos.config.nixpkgs.hostPlatform.system}."nixos-${name}" = nixos.config.system.build.toplevel;
          }
        )
        config.flake.nixosConfigurations
    );
  };
}
