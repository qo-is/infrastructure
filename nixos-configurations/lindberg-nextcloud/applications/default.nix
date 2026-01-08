{ pkgs, ... }:
{
  qois.postgresql.package = pkgs.postgresql_14;

  qois.cloud = {
    enable = true;
    package = pkgs.nextcloud32;
  };
}
