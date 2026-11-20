function uefi { Start-Process shutdown -ArgumentList '/r /fw /t 0' -Verb RunAs }
