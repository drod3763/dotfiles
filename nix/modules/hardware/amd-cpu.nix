# Ryzen 9 7950X3D now, 9950X3D later (D-17). Both have 3D V-Cache on one CCD.
{
  flake.modules.nixos.amd-cpu = {
    hardware.cpu.amd.updateMicrocode = true;
    hardware.enableRedistributableFirmware = true;
    boot.kernelModules = [ "kvm-amd" ];

    # amd_x3d_vcache (Linux 6.13+) tells the scheduler which CCD to prefer.
    # "cache" favors the V-Cache CCD, which helps games; "frequency" favors
    # the faster CCD. The write is skipped with a warning if the driver is
    # missing.
    systemd.tmpfiles.rules = [
      "w /sys/bus/platform/drivers/amd_x3d_vcache/AMDI0101:00/amd_x3d_mode - - - - cache"
    ];
  };
}
