{
  inputs,
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkDefault
    mkOption
    optional
    ;
  inherit (lib.types) str;
  cfg = config.qois.prometheus;
in
{
  imports = [ inputs.srvos.nixosModules.roles-prometheus ];

  options.qois.prometheus = {
    enable = mkEnableOption "Enable prometheus";

    domain = mkOption {
      type = str;
      default = "prometheus.qo.is";
      description = "Domain, under which the web UI is served.";
    };
  };

  config = mkIf cfg.enable {
    qois.telegraf.monitoring.enable = mkDefault true;

    services.prometheus = {
      enable = true;
      checkConfig = true;
      extraFlags = [ "--log.level=warn" ];
      webExternalUrl = "https://${cfg.domain}/";
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
      ]
      ++ optional config.qois.loki.enable {
        job_name = "loki";
        static_configs = [
          { targets = [ "localhost:${builtins.toString config.qois.loki.port}" ]; }
        ];
      };
    };
  };
}
