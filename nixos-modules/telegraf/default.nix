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
        };
      };
    };
  };
}
