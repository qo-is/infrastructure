{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../base-minimal
    ./applications.nix
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
}
