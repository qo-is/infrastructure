{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  routerCfg = config.qois.router;
  dhcpCfg = config.qois.router.dhcp;
  cfg = config.qois.router.recursiveDns;
in
{
  options.qois.router.recursiveDns = {
    enable = mkEnableOption "router recursive dns service";

    networkIdIp = mkOption {
      type = types.str;
      example = "192.168.0.0";
      description = ''
        Network ID IP of local network.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.unbound =
      let
        revIpDomain = concatStringsSep "." (reverseList (take 3 (splitString "." cfg.networkIdIp)));
      in
      {
        enable = true;
        settings = {
          server = {
            interface = [
              "127.0.0.1"
              routerCfg.internalRouterIP
            ];
            access-control = [
              ''"127.0.0.0/24" allow''
              ''"${cfg.networkIdIp}/${toString routerCfg.internalPrefixLength}" allow''
            ];
            do-not-query-localhost = "no";
            private-domain = [
              "${dhcpCfg.localDomain}."
              "${revIpDomain}.in-addr.arpa."
            ];
            domain-insecure = [
              "${dhcpCfg.localDomain}."
              "${revIpDomain}.in-addr.arpa."
            ];
            local-zone = ''"${revIpDomain}.in-addr.arpa" transparent'';
          };

          forward-zone = [
            {
              name = "${dhcpCfg.localDomain}.";
              forward-addr = "127.0.0.1@${toString dhcpCfg.localDnsPort}";
            }
            {
              name = "${revIpDomain}.in-addr.arpa.";
              forward-addr = "127.0.0.1@${toString dhcpCfg.localDnsPort}";
            }
          ];
        };
      };
  };
}
