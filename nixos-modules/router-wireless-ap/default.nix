{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.qois.router.wireless;
in
{
  options.qois.router.wireless = {
    enable = mkEnableOption "router wireless service";

    wleInterface24Ghz = mkOption {
      type = with types; nullOr str;
      default = null;
      example = "wlp1";
      description = ''
        Wireless interface name for 2.4 GHz wireless band.
      '';
    };

    ssid = mkOption {
      type = types.str;
      example = "MyNetwork";
      description = ''
        Wireless network SSID.
      '';
    };

    passphrase = mkOption {
      type = types.str;
      description = ''
        Passphrase of wireless network. May be encrypted with <literal>wpa_passphrase &lt;wleSSID&gt; &lt;passphrase&gt;</literal>.
      '';
    };

    regulatoryCountryCode = mkOption {
      type = types.str;
      default = "US";
      description = ''
        Regulatory wireless country code.
      '';
    };
  };

  config =
    let
      wle24GhzEnabled = cfg.wleInterface24Ghz != null;
    in
    mkIf cfg.enable {
      boot.extraModprobeConfig = ''
        options cfg80211 ieee80211_regdom=${cfg.regulatoryCountryCode}
      '';

      systemd.services.hostapd.after = [ "lan-netdev.service" ];

      services.hostapd = {
        enable = wle24GhzEnabled;

        radios.${cfg.wleInterface24Ghz} = {
          channel = 6;
          wifi4.enable = true;
          wifi4.capabilities = [
            "HT40-"
            "HT40+"
            "SHORT-GI-40"
            "TX-STBC"
            "RX-STBC1"
            "DSSS_CCK-40"
          ];
          wifi5.enable = false;
          networks.${cfg.wleInterface24Ghz} = {
            # hostapd requires bss to have names with the interface.
            ssid = cfg.ssid;
            authentication = {
              mode = "wpa2-sha256";
              enableRecommendedPairwiseCiphers = true;
              wpaPasswordFile = /secrets/wifi_${cfg.ssid};
            };
            settings = {
              wme_enabled = 1;
              ieee80211w = 0;
              sae_require_mfp = 0;
              wpa_key_mgmt = lib.mkForce "WPA-PSK";
              wpa_pairwise = lib.mkForce "CCMP";
              rsn_pairwise = lib.mkForce "CCMP";
              bridge = "lan";
            };
          };

          settings = {
            wme_enabled = 1;
            ieee80211w = 0;
            sae_require_mfp = 0;
            wpa = 2;
            wpa_key_mgmt = lib.mkForce "WPA-PSK";
            wpa_pairwise = lib.mkForce "CCMP";
            rsn_pairwise = lib.mkForce "CCMP";
          };
        };
      };
    };
}
