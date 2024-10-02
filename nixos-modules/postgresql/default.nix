{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.qois.postgresql;
in
with lib;
{
  options.qois.postgresql = {
    enable = mkEnableOption ''Enable postgresql services with defaults'';
  };

  config = mkIf cfg.enable {
    services.postgresql.enable = true;
    services.postgresqlBackup.enable = true;
    qois.backup-client.includePaths = [ config.services.postgresqlBackup.location ];
  };
}
