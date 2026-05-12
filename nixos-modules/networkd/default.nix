{ lib, config, ... }:
let
  inherit (lib) mkEnableOption;
in
{
  options.qois.networkd.enable = mkEnableOption "systemd-networkd";

  config.networking.useNetworkd = config.qois.networkd.enable;
}
