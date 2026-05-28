{ lib, config, ... }:
let
  inherit (lib) mkEnableOption mkIf mkMerge;
in
{
  options.qois.networkd.enable = mkEnableOption "systemd-networkd";

  config = mkMerge [
    { networking.useNetworkd = config.qois.networkd.enable; }
    (mkIf config.qois.networkd.enable {
      services.resolved = {
        enable = true;
        llmnr = "false";
        fallbackDns = [
          # dns.switch.ch
          "130.59.31.248"
          "130.59.31.251"
        ];
      };
    })
  ];
}
