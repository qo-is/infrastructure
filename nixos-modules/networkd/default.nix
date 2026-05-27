{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkIf;
in
{
  options.qois.networkd.enable = mkEnableOption "systemd-networkd";

  config = mkIf config.qois.networkd.enable {
    networking.useNetworkd = true;

    services.resolved = {
      enable = true;
      llmnr = "false";
      fallbackDns = [
        # dns.switch.ch
        "130.59.31.248"
        "130.59.31.251"
      ];
    };
  };
}
