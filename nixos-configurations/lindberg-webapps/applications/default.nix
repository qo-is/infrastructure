{ pkgs, ... }:
{

  imports = [ ];

  qois.nginx.behindLoadbalancer = true;
  qois.vault.enable = true;
  qois.git.enable = true;
  qois.static-page.enable = true;
  qois.postgresql.package = pkgs.postgresql_18;
  qois.postgresql.upgradeFrom = pkgs.postgresql_15;

  qois.prometheus.enable = true;
  qois.grafana.enable = true;
  qois.loki.enable = true;
  qois.alertmanager.enable = true;

}
