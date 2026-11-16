# titan: desktop, dual boot with Windows 11 LTSC (D-15).
{ config, ... }:
{
  configurations.nixos.titan.module = {
    imports = with config.flake.modules.nixos; [
      nix-settings
      boot
      locale
      networking
      users
      nvidia
      amd-cpu
      btrfs-luks
      niri
      app-services
      nix-ld
      ./_hardware.nix
    ];

    networking.hostName = "titan";

    # Windows boots from its own ESP on the same disk (D-11). Find the
    # handle once from the EFI shell entry with `map -c` (the FS alias whose
    # ESP holds \EFI\Microsoft), then uncomment:
    # boot.loader.systemd-boot.windows."11-ltsc" = {
    #   title = "Windows 11 LTSC";
    #   efiDeviceHandle = "HD0b";
    # };

    # The NixOS release this machine was first installed with. Set it on
    # install day and never change it afterward.
    system.stateVersion = "26.05";
  };
}
