{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf mkOption;
  inherit (lib.types) str;
  cfg = config.qois.vector;
in
{
  options.qois.vector = {
    enable = mkEnableOption "Vector log shipping agent";

    lokiEndpoint = mkOption {
      type = str;
      default = "http://lindberg-webapps.backplane.net.qo.is:${toString config.qois.loki.port}";
      description = "Loki push API endpoint logs are shipped to.";
    };
  };

  config = mkIf cfg.enable {
    services.vector = {
      enable = true;
      journaldAccess = true;

      settings = {
        sources.journald.type = "journald";

        transforms.with_unit_label = {
          type = "remap";
          inputs = [ "journald" ];
          source = ''.unit = to_string(._SYSTEMD_UNIT) ?? to_string(._SYSLOG_IDENTIFIER) ?? "none"'';
        };

        sinks.loki = {
          type = "loki";
          inputs = [ "with_unit_label" ];
          endpoint = cfg.lokiEndpoint;
          encoding.codec = "text";
          labels = {
            host = config.networking.hostName;
            unit = "{{ unit }}";
          };
        };
      };
    };
  };
}
