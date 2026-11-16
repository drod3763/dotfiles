# Systems that get perSystem outputs (formatter, checks). NixOS hosts set
# their own platform in their hardware file.
{
  systems = [
    "x86_64-linux"
    "aarch64-darwin"
  ];
}
