{ pkgs, ... }:
{
  qois.postgresql.package = pkgs.postgresql_14;
  qois.telegraf.enable = true;

  qois.cloud = {
    enable = true;
    package = pkgs.nextcloud32;
  };
}
