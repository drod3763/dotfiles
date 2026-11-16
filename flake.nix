{
  description = "NixOS hosts, dendritic layout: every file under nix/modules is a flake-parts module";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    import-tree.url = "github:vic/import-tree";
  };

  # import-tree loads every .nix file under nix/modules, except paths with a
  # `_`-prefixed component (used for plain NixOS files such as _hardware.nix).
  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./nix/modules);
}
