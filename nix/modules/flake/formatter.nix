# `nix fmt` uses the same formatter as home/treefmt.toml.
{
  perSystem =
    { pkgs, ... }:
    {
      formatter = pkgs.nixpkgs-fmt;
    };
}
