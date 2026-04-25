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
    qois.telegraf.monitoring.enable = lib.mkDefault true;

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
        {
          job_name = "telegraf";
          static_configs = [
            {
              targets = [
                "calanda.backplane.net.qo.is:9273"
                "cyprianspitz.backplane.net.qo.is:9273"
                "lindberg.backplane.net.qo.is:9273"
                "lindberg-build.backplane.net.qo.is:9273"
                "lindberg-nextcloud.backplane.net.qo.is:9273"
                "lindberg-webapps.backplane.net.qo.is:9273"
              ];
            }
          ];
        }
      ];
    };
  };
}
