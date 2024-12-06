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
    # Note: this module is auto-enabled if postgres is used.
    package = mkPackageOption pkgs "postgresql" {
      example = "postgresql_15";
      default = null;
    };
  };

  config = mkIf config.services.postgresql.enable {
    services.postgresql.package = cfg.package;
    services.postgresqlBackup.enable = true;
    qois.backup-client.includePaths = [ config.services.postgresqlBackup.location ];
  };
}
