{
  inputs,
  config,
  lib,
  pkgs,
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

  options.qois.telegraf = {
    enable = lib.mkEnableOption "telegraf metrics agent";

    serviceInputs = lib.mkOption {
      # Same type as services.telegraf.extraConfig, so that several modules declaring
      # the same input concatenate rather than overriding each other.
      type = (pkgs.formats.toml { }).type;
      default = { };
      description = ''
        Telegraf inputs contributed by service modules, as opposed to the host-level
        inputs of this module and srvos. Module tests restrict telegraf to these.
      '';
    };
  };

  config = lib.mkMerge [
    { services.telegraf.extraConfig.inputs = cfg.serviceInputs; }

    (lib.mkIf cfg.enable {
      networking.firewall.interfaces."wg-backplane".allowedTCPPorts = [ 9273 ];

      services.telegraf = {
        enable = true;
        extraConfig = {
          outputs.prometheus_client.expiration_interval = "10m";
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
    })
  ];
}
