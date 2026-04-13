{
  config,
  lib,
  ...
}:
let
  cfg = config.qois.telegraf;
in
{
  options.qois.telegraf.enable = lib.mkEnableOption "telegraf metrics agent";

  config = lib.mkIf cfg.enable {
    networking.firewall.interfaces."wg-backplane".allowedTCPPorts = [ 9273 ];

    services.telegraf = {
      enable = true;
      extraConfig = {
        agent.interval = "60s";
        inputs = {
          system = { };
          mem = { };
          cpu = [
            {
              percpu = false;
              totalcpu = true;
              collect_cpu_time = false;
            }
          ];
        };
        outputs.prometheus_client = [
          {
            listen = ":9273";
            metric_version = 2;
          }
        ];
      };
    };
  };
}
