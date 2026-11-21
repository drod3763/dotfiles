{
  flake.modules.nixos.locale = {
    time.timeZone = "America/New_York";
    i18n.defaultLocale = "en_US.UTF-8";
    # Windows keeps the hardware clock in local time. Linux uses UTC, so
    # dual-boot clocks drift by the UTC offset unless one side changes.
    # Set Windows to UTC instead (RealTimeIsUniversal); see the logbook.
  };
}
