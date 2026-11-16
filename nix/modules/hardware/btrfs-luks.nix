# Disk layout from D-12. The installer names partitions with GPT labels, so
# nothing here depends on UUIDs or on how Linux numbers the NVMe drives.
#   nixos-esp   FAT32, mounted at /boot
#   nixos-root  LUKS2 -> btrfs: @root, @nix, @home, @swap
#   nixos-data  LUKS2 -> btrfs: @data, unlocked by a keyfile on root
{
  flake.modules.nixos.btrfs-luks =
    let
      btrfsOpts = subvol: [
        "subvol=${subvol}"
        "compress=zstd"
        "noatime"
      ];
    in
    {
      boot.initrd.luks.devices.cryptroot = {
        device = "/dev/disk/by-partlabel/nixos-root";
        allowDiscards = true;
      };

      # The data disk unlocks after root is mounted, from a keyfile stored on
      # the encrypted root, so only one passphrase is typed at boot. It goes
      # through /etc/crypttab rather than the initrd so the key never lands
      # on the unencrypted ESP.
      environment.etc.crypttab.text = ''
        cryptdata /dev/disk/by-partlabel/nixos-data /etc/secrets/data.key luks,discard
      '';

      fileSystems = {
        "/" = {
          device = "/dev/mapper/cryptroot";
          fsType = "btrfs";
          options = btrfsOpts "@root";
        };
        "/nix" = {
          device = "/dev/mapper/cryptroot";
          fsType = "btrfs";
          options = btrfsOpts "@nix";
        };
        "/home" = {
          device = "/dev/mapper/cryptroot";
          fsType = "btrfs";
          options = btrfsOpts "@home";
        };
        "/swap" = {
          device = "/dev/mapper/cryptroot";
          fsType = "btrfs";
          options = [
            "subvol=@swap"
            "noatime"
          ];
        };
        "/boot" = {
          device = "/dev/disk/by-partlabel/nixos-esp";
          fsType = "vfat";
          options = [
            "fmask=0077"
            "dmask=0077"
          ];
        };
        "/data" = {
          device = "/dev/mapper/cryptdata";
          fsType = "btrfs";
          # nofail: a problem with the data disk shouldn't stop boot.
          options = (btrfsOpts "@data") ++ [ "nofail" ];
        };
      };

      # The installer creates the swapfile with `btrfs filesystem mkswapfile`
      # and picks its size, so the config doesn't depend on RAM size.
      swapDevices = [{ device = "/swap/swapfile"; }];
      zramSwap.enable = true;

      services.fstrim.enable = true;
      services.btrfs.autoScrub = {
        enable = true;
        fileSystems = [
          "/"
          "/data"
        ];
      };
    };
}
