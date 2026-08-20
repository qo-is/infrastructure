{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkPackageOption;
  cfg = config.qois.postgresql;
  pgCfg = config.services.postgresql;
  pgServiceCfg = config.systemd.services.postgresql;
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
      inherit (pgServiceCfg) path;
      environment.PGDATA = pgServiceCfg.environment.PGDATA;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        inherit (pgServiceCfg.serviceConfig)
          User
          Group
          RuntimeDirectory
          StateDirectory
          StateDirectoryMode
          ;
        # The analyze instance below reuses postgresql.service's own ExecStart, so it
        # listens on the same /run/postgresql socket. Give this unit a private, empty
        # /run/postgresql and no network access so that socket is never reachable by
        # any other service while the analyze instance is briefly up.
        TemporaryFileSystem = [ "/run/postgresql" ];
        PrivateNetwork = true;
        # pg_upgrade writes its logs and dumps into the current directory.
        WorkingDirectory = pgCfg.dataDir;
      };
      script = ''
        set -euo pipefail

        ${pgServiceCfg.preStart}

        pg_upgrade \
          --old-datadir "${oldDataDir}" \
          --new-datadir "${pgCfg.dataDir}" \
          --old-bindir "${cfg.upgradeFrom}/bin" \
          --new-bindir "${pgCfg.finalPackage}/bin"

        ${pgServiceCfg.serviceConfig.ExecStart} &
        serverPid=$!
        until pg_isready -q; do sleep 0.5; done
        vacuumdb --all --analyze-in-stages
        kill -s ${pgServiceCfg.serviceConfig.KillSignal} "$serverPid"
        wait "$serverPid"
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
