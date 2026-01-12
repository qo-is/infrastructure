{
  config,
  pkgs,
  options,
  ...
}:
let

  inherit (config.qois.services.postgres) storage exposes settings;
in
{

  options.qois.services.postgres.settings = {
    databases = options.services.postgresql.ensureDatabases;
    #TODO
  };

  config = {
    services.postgresql = {
      enable = true;
      package = pkgs.postgresql_17;

      enableTCPIP = true;
      settings.port = exposes.postgres.port;

      dataDir = "${storage.postgresql-backup.path}/${config.services.postgresql.package.psqlSchema}";

      enableJIT = true;

      ensureDatabases = settings.databases;

      # TODO: Add users and passwords, see
      #  https://discourse.nixos.org/t/set-password-for-a-postgresql-user-from-a-file-agenix/41377/10
    };

    services.prometheus.exporters.postgres = {
      enable = true;
      inherit (exposes.postgres-prometheus) port;
    };

    services.postgresqlBackup = {
      enable = true;
      location = storage.postgresql-backup.path;
    };
  };
}
