# Based on https://github.com/jgillich/nixos/blob/master/services/ppp.nix
# Tipps and tricks under https://www.hackster.io/munoz0raul/how-to-use-gsm-3g-4g-in-embedded-linux-systems-9047cf#toc-configuring-the-ppp-files-5
{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.qois.wwan;

  mbim-ip-configured = pkgs.writeScriptBin "mbim-ip-configured" (
    ''
      #!${pkgs.stdenv.shell}
      MBIM_INTERFACE=${cfg.mbimInterface}
    ''
    + (readFile ./mbim-ip.bash)
  );

  mbim-check-status = pkgs.writeScriptBin "mbim-check-status" ''
    #!${pkgs.stdenv.shell}
    if ! systemctl is-active --quiet wwan.service; then
      # Skip check if wwan is not running
      exit 0
    fi

    if ! mbim-network ${cfg.mbimInterface} status | grep -q "Status: activated"; then
      echo "WWAN device is currently in disabled state, triggering restart."
      systemctl restart wwan.service
    fi
  '';
in
{
  options.qois.wwan = {
    enable = mkEnableOption "wwan client service";

    apn = mkOption {
      type = types.str;
      description = ''
        APN domain of provider.
      '';
    };

    apnUser = mkOption {
      type = types.str;
      default = "";
      description = ''
        APN username (optional).
      '';
    };

    apnPass = mkOption {
      type = types.str;
      default = "";
      description = ''
        APN password (optional).
      '';
    };

    apnAuth = mkOption {
      type = types.enum [
        "PAP"
        "CHAP"
        "MSCHAPV2"
        ""
      ];
      default = "";
      description = ''
        APN authentication type, one of ${concatMapStringsSep ", " show values} (optional).
      '';
    };

    mbimProxy = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to use the mbim proxy or not.
      '';
    };

    mbimInterface = mkOption {
      type = types.str;
      default = "/dev/cdc-wdm0";
      description = ''
        MBIM Interface which the connection will use.
      '';
    };

    networkInterface = mkOption {
      type = types.str;
      description = "Name of the WWAN network interface";
    };
  };

  config = mkIf cfg.enable {
    systemd.services = {
      "wwan" = {
        description = "WWAN connectivity";
        wantedBy = [ "network.target" ];
        bindsTo = [ "network-addresses-${cfg.networkInterface}.service" ];
        path = with pkgs; [
          libmbim
          iproute
        ];

        serviceConfig = {
          ExecStart = "${mbim-ip-configured}/bin/mbim-ip-configured start ${cfg.networkInterface}";
          ExecStop = "${mbim-ip-configured}/bin/mbim-ip-configured stop  ${cfg.networkInterface}";

          RemainAfterExit = true;
        };
      };
      "wwan-check" = {
        description = "Check WWAN connectivity and restart if disabled";
        path = with pkgs; [ libmbim ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${mbim-check-status}/bin/mbim-check-status";
        };
      };
    };
    systemd.timers."wwan-check" = {
      description = "WWAN connectivity check";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        Unit = "wwan-check";
        OnBootSec = "2m";
        OnUnitActiveSec = "1m";
      };
    };

    environment.etc."mbim-network.conf".text = ''
      APN=${cfg.apn}
      APN_USER=${cfg.apnUser}
      APN_PASS=${cfg.apnPass}
      APN_AUTH=${cfg.apnAuth}
      PROXY=${optionalString cfg.mbimProxy "yes"}
    '';

    networking.interfaces.${cfg.networkInterface}.useDHCP = false;
  };
}
