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
  };

  config = mkIf cfg.enable {
    services.telegraf.extraConfig.inputs = {
      inherit (cfg) http_response;

      ping = map (host: {
        interval = cfg.pingInterval;
        count = 1;
        method = "native";
        urls = [ host ];
      }) cfg.ping;
    };
  };
}
