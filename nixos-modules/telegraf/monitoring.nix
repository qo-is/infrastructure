{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mapAttrsToList
    mkOption
    ;
  inherit (lib.types) listOf str anything;
  cfg = config.qois.telegraf.monitoring;
  backplaneNet = config.qois.meta.network.virtual.backplane;
  backplaneHostnames = mapAttrsToList (
    name: _host: "${name}.${backplaneNet.domain}"
  ) backplaneNet.hosts;
in
{
  options.qois.telegraf.monitoring = {
    enable = mkEnableOption "central blackbox monitoring via telegraf";
    http_response = mkOption {
      type = listOf anything;
      default = [
        {
          urls = [ "https://cloud.qo.is/login" ];
          response_string_match = "Nextcloud";
        }
        {
          urls = [ "https://git.qo.is" ];
          response_string_match = "Forgejo";
        }
        {
          urls = [ "https://vault.qo.is/alive" ];
          response_string_match = "\"20";
        }
        {
          urls = [ "https://monitoring.qo.is/login" ];
          response_string_match = "Grafana";
        }
        {
          urls = [ "https://attic.qo.is" ];
        }
      ];
    };
    ping = mkOption {
      type = listOf str;
      default = backplaneHostnames;
    };
    pingInterval = mkOption {
      type = str;
      default = "1m";
    };
    buildStatus = mkOption {
      type = listOf anything;
      default = [
        {
          owner = "qo.is";
          repo = "infrastructure";
          branch = "main";
        }
      ];
      description = "Forgejo repos/branches to report the latest combined commit status for.";
    };
  };

  config = mkIf cfg.enable {
    services.telegraf.extraConfig = {
      inputs = {
        inherit (cfg) http_response;

        ping = map (host: {
          interval = cfg.pingInterval;
          count = 1;
          method = "native";
          urls = [ host ];
        }) cfg.ping;

        http = map (b: {
          urls = [ "https://git.qo.is/api/v1/repos/${b.owner}/${b.repo}/commits/${b.branch}/status" ];
          tags = {
            inherit (b) owner repo branch;
          };
          data_format = "json_v2";
          timeout = "10s";
          interval = "5m";
          json_v2 = [
            {
              measurement_name = "forgejo_build_status";
              field = [ { path = "state"; } ];
              tag = [ { path = "state"; } ];
            }
          ];
        }) cfg.buildStatus;
      };

      processors.enum = [
        {
          namepass = [ "forgejo_build_status" ];
          mapping = [
            {
              fields = [ "state" ];
              dest = "value";
              default = 4;
              value_mappings = {
                success = 0;
                pending = 1;
                warning = 2;
                failure = 3;
                error = 3;
              };
            }
          ];
        }
      ];
    };
  };
}
