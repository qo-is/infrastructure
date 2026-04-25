{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkPackageOption;
  cfg = config.qois.postgresql;
in
{
  options.qois.postgresql = {
    # Note: this module is auto-enabled if postgres is used.
    package = mkPackageOption pkgs "postgresql" {
      example = "postgresql_15";
      default = null;
    };
  };

  config = mkIf config.services.postgresql.enable {
    services.postgresql = {
      package = cfg.package;
      ensureUsers = [
        { name = "telegraf"; }
      ];
    };

    services.postgresqlBackup.enable = true;
    qois.backup-client.includePaths = [ config.services.postgresqlBackup.location ];

    systemd.services.telegraf-postgresql-setup = {
      description = "Grant pg_read_all_stats to telegraf PostgreSQL user";
      wantedBy = [ "telegraf.service" ];
      before = [ "telegraf.service" ];
      after = [
        "postgresql.service"
        "postgresql-setup.service"
      ];
      requires = [ "postgresql.service" ];
      serviceConfig = {
        Type = "oneshot";
        User = "postgres";
        ExecStart = "${config.services.postgresql.package}/bin/psql -c \"GRANT pg_read_all_stats TO telegraf\" postgres";
        RemainAfterExit = true;
      };
    };

    services.telegraf.extraConfig.inputs.postgresql = [
      {
        address = "host=/run/postgresql user=telegraf dbname=postgres sslmode=disable";
      }
    ];
  };
}
