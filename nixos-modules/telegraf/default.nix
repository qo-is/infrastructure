{
  inputs,
  config,
  lib,
  ...
}:
let
  cfg = config.qois.telegraf;
in
{
  imports = [
    inputs.srvos.nixosModules.mixins-telegraf
    ./monitoring.nix
  ];

  options.qois.telegraf.enable = lib.mkEnableOption "telegraf metrics agent";

  config = lib.mkIf cfg.enable {
    networking.firewall.interfaces."wg-backplane".allowedTCPPorts = [ 9273 ];

    services.telegraf = {
      enable = true;
      extraConfig = {
        inputs = {
          cpu = [
            {
              percpu = false;
              totalcpu = true;
              collect_cpu_time = false;
            }
          ];
          net = { };
          nginx.urls = lib.mkIf config.services.nginx.statusPage (
            lib.mkForce [
              "http://localhost:${toString config.services.nginx.defaultHTTPListenPort}/nginx_status"
            ]
          );
          systemd_units.details = true;
        };
      };
    };
  };
}
