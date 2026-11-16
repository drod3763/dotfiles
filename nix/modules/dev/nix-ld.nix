# Lets prebuilt Linux binaries (mise tools, language servers, npm packages
# with native code) find a dynamic loader and common libraries.
{
  flake.modules.nixos.nix-ld = {
    programs.nix-ld.enable = true;
  };
}
