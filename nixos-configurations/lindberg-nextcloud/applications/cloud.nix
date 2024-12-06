{ config, pkgs, ... }:
let
  host = "cloud.qo.is";
in
{

  imports = [ ../../../defaults/nextcloud ];

  services.postgresql.enable = true;

  services.nextcloud = {
    hostName = host;
    package = pkgs.nextcloud30;
    settings.default_phone_region = "CH";
  };
  services.nginx.virtualHosts."${host}" = {
    forceSSL = true;
    enableACME = true;
    kTLS = true;
  };
}
