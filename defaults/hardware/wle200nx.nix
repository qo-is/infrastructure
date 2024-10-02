{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.hostapd.extraConfig = ''
    ht_capab=[HT40-][HT40+][SHORT-GI-40][TX-STBC][RX-STBC1][DSSS_CCK-40]
  '';
}
