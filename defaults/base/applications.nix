{
  config,
  lib,
  pkgs,
  ...
}:

{
  environment.systemPackages =
    with pkgs;
    [
      pciutils
      dmidecode
      smartmontools
      iw
      efibootmgr
      efitools
      efivar
      pwgen
      powertop
      lm_sensors
    ]
    ++ [
      # Filesystem & Disk Utilities
      hdparm
      smartmontools
    ]
    ++ [
      # Networking Utilities
      tcpdump
    ];
}
