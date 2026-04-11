{
  config,
  lib,
  ...
}:
let
  cfg = config.qois.prometheus;
in
{
  options.qois.prometheus = {
    enable = lib.mkEnableOption "Enable prometheus";
  };

  config = lib.mkIf cfg.enable {
    services.prometheus = {
      enable = true;
      checkConfig = true;
      scrapeConfigs = [
        {
          job_name = "prometheus";
          static_configs = [
            { targets = [ "localhost:${builtins.toString config.services.prometheus.port}" ]; }
          ];
        }
      ]
      ++ lib.optional config.services.telegraf.enable {
        job_name = "self";
        static_configs = [ { targets = [ "localhost:9273" ]; } ];
      };
    };
  };
}
