{ pkgs, ... }:
{
  qois.nginx.behindLoadbalancer = true;
  qois.postgresql.package = pkgs.postgresql_18;
  qois.postgresql.upgradeFrom = pkgs.postgresql_14;

  qois.cloud = {
    enable = true;
    package = pkgs.nextcloud34;
  };
}
