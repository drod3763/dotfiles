# systemd-boot on NixOS's own ESP (D-11). The initrd is systemd-based (the
# only kind nixpkgs has now), so FIDO2/TPM unlock (D-08) can be added later.
{
  flake.modules.nixos.boot = {
    boot.loader = {
      systemd-boot = {
        enable = true;
        # Keeps old generations from filling the 1 GiB ESP.
        configurationLimit = 10;
        # The EFI shell's `map -c` lists device handles. Use it once to find
        # the Windows ESP's handle for the host's
        # boot.loader.systemd-boot.windows entry.
        edk2-uefi-shell.enable = true;
      };
      efi.canTouchEfiVariables = true;
    };
  };
}
