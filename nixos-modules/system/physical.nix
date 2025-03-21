{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.qois.system.physical;
in
with lib;
{
  options.qois.system.physical.enable = mkEnableOption "Enable qois physical system configuration";

  config = lib.mkIf cfg.enable {
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

    # System Services
    services.fwupd.enable = true;

    services.smartd = {
      enable = true;
      notifications.mail = {
        enable = true;
        mailer = "${pkgs.msmtp}/bin/sendmail";
        sender = "system@qo.is";
        recipient = "sysadmin@qo.is";
      };
    };
  };
}
