{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf mkOption;
  inherit (lib.types) port str;
  cfg = config.qois.loki;
in
{
  options.qois.loki = {
    enable = mkEnableOption "Loki log aggregation";

    port = mkOption {
      type = port;
      default = 3100;
      description = "HTTP port Loki listens on for pushes and queries.";
    };

    retentionPeriod = mkOption {
      type = str;
      default = "744h";
      description = "How long to retain logs before deletion.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall.interfaces."wg-backplane".allowedTCPPorts = [ cfg.port ];

    services.loki = {
      enable = true;

      configuration = {
        auth_enabled = false;

        server.http_listen_port = cfg.port;

        common = {
          replication_factor = 1;
          path_prefix = "/var/lib/loki";
          ring.kvstore.store = "inmemory";
        };

        schema_config.configs = [
          {
            from = "2024-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];

        storage_config.filesystem.directory = "/var/lib/loki/chunks";

        limits_config = {
          retention_period = cfg.retentionPeriod;
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };

        compactor = {
          working_directory = "/var/lib/loki/compactor";
          retention_enabled = true;
          delete_request_store = "filesystem";
        };
      };
    };
  };
}
