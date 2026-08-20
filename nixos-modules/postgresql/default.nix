{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkPackageOption escapeShellArgs;
  cfg = config.qois.postgresql;
  pgCfg = config.services.postgresql;
  oldDataDir = "/var/lib/postgresql/${cfg.upgradeFrom.psqlSchema}";
in
{
  options.qois.postgresql = {
    # Note: this module is auto-enabled if postgres is used.
    package = mkPackageOption pkgs "postgresql" {
      example = "postgresql_15";
      default = null;
    };

    upgradeFrom = mkPackageOption pkgs "postgresql" {
      nullable = true;
      default = null;
      example = "postgresql_15";
      extraDescription = ''
        Set to the previously-deployed postgresql package while performing a major-version
        upgrade. A preflight service pg_upgrades data from this package's data directory into
        the new one before postgresql.service starts. Remove this option once the upgrade is
        confirmed successful.
      '';
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

    systemd.services.postgresql-upgrade = mkIf (cfg.upgradeFrom != null) {
      description = "Upgrade PostgreSQL data from ${cfg.upgradeFrom.psqlSchema} to ${cfg.package.psqlSchema}";
      before = [ "postgresql.service" ];
      requiredBy = [ "postgresql.service" ];
      unitConfig.ConditionPathExists = "!${pgCfg.dataDir}/PG_VERSION";
      environment.PGDATA = pgCfg.dataDir;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
        Group = "postgres";
        StateDirectory = "postgresql postgresql/${cfg.package.psqlSchema}";
        WorkingDirectory = pgCfg.dataDir;
      };
      script = ''
        set -euo pipefail

        "${pgCfg.finalPackage}/bin/initdb" -U "${pgCfg.superUser}" ${escapeShellArgs pgCfg.initdbArgs}
        "${pgCfg.finalPackage}/bin/pg_upgrade" \
          --old-datadir "${oldDataDir}" \
          --new-datadir "${pgCfg.dataDir}" \
          --old-bindir "${cfg.upgradeFrom}/bin" \
          --new-bindir "${pgCfg.finalPackage}/bin"

        # Analyze the new cluster before postgresql.service opens it up to real traffic,
        # via a throwaway local-socket-only instance (pg_upgrade's own generated
        # analyze_new_cluster.sh script recommends this before serving queries).
        "${pgCfg.finalPackage}/bin/pg_ctl" -D "${pgCfg.dataDir}" -w \
          -o "-c listen_addresses= -c unix_socket_directories=${pgCfg.dataDir}" start
        "${pgCfg.finalPackage}/bin/vacuumdb" -h "${pgCfg.dataDir}" --all --analyze-in-stages
        "${pgCfg.finalPackage}/bin/pg_ctl" -D "${pgCfg.dataDir}" -w stop
      '';
    };

    systemd.services.telegraf-postgresql-setup = {
      description = "Grant pg_read_all_stats to telegraf PostgreSQL user";
      wantedBy = [ "telegraf.service" ];
      before = [ "telegraf.service" ];
      after = [ "postgresql.target" ];
      requires = [ "postgresql.target" ];
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
