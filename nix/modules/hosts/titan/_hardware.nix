# Placeholder until install day. The installer replaces this file with the
# output of `nixos-generate-config --no-filesystems --show-hardware-config`.
# Filesystems come from the btrfs-luks module, not from here.
# The leading `_` keeps import-tree from loading it as a flake-parts module.
{ lib, ... }:
{
  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "ahci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
