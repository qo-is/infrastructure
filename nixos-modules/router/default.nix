{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.qois.router;
in
{
  options.qois.router = {
    enable = mkEnableOption "router service";

    wanInterface = mkOption {
      type = with types; nullOr str;
      example = "enp0";
      default = null;
      description = ''
        WAN interface name.
      '';
    };

    wirelessInterfaces = mkOption {
      type = types.listOf types.str;
      example = [
        "wlp1"
        "wlp2"
      ];
      default = [ ];
      description = ''
        Wireless interfaces names.
      '';
    };

    lanInterfaces = mkOption {
      type = types.listOf types.str;
      example = [
        "enp1"
        "enp2"
      ];
      default = [ ];
      description = ''
        LAN interfaces names.
      '';
    };

    internalRouterIP = mkOption {
      type = types.str;
      example = "192.168.0.1";
      description = ''
        Internal IP of router.
      '';
    };

    internalPrefixLength = mkOption {
      type = types.addCheck types.int (n: n >= 0 && n <= 32);
      default = 24;
      description = ''
        Subnet mask of the network, specified as the number of
        bits in the prefix (<literal>24</literal>).
      '';
    };

    internalBridgeInterfaceName = mkOption {
      type = types.str;
      default = "lan";
      description = ''
        Name of the virtual internal interface.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking = {
      enableIPv6 = false; # TODO
      nat =
        if cfg.wanInterface == null then
          { }
        else
          {
            enable = true;
            externalInterface = cfg.wanInterface;
            internalInterfaces = [ cfg.internalBridgeInterfaceName ];
          };

      bridges.${cfg.internalBridgeInterfaceName}.interfaces = cfg.lanInterfaces; # Note: The wlp interface is added by hostapd.
      interfaces.${cfg.internalBridgeInterfaceName} = {
        ipv4 = {
          addresses = [
            {
              address = cfg.internalRouterIP;
              prefixLength = cfg.internalPrefixLength;
            }
          ];
        };
      };
      firewall.trustedInterfaces = [ cfg.internalBridgeInterfaceName ];
    };
  };
}
