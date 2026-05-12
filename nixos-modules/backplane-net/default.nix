{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    pipe
    ;
  inherit (lib.types) number str;
  cfg = config.qois.backplane-net;
  hostName = config.networking.hostName;
  netConfig = config.qois.meta.network.virtual.${cfg.netName};
  hostNetConfig = netConfig.hosts.${hostName};
  interface = "wg-${cfg.netName}";
  wgService = [ "wireguard-${interface}.service" ];
in
{
  options.qois.backplane-net = {
    enable = mkEnableOption "Enable backplane server services";
    netName = mkOption {
      description = "Network Name";
      type = str;
      default = "backplane";
    };
    port = mkOption {
      description = "Wireguard Default Port";
      type = number;
      default = 51825;
    };
  };

  config = mkIf cfg.enable {
    sops.secrets."wgautomesh/gossip-secret".restartUnits = [ "wgautomesh.service" ];

    # TODO: Migrate to the networkd wireguard backend once generatePrivateKeyFile
    # and the wgautomesh service dependency chain are reworked for networkd.
    networking.wireguard.useNetworkd = false;
    networking.wireguard.enable = true;
    networking.wireguard.interfaces."wg-${cfg.netName}" = {
      ips = [ "${hostNetConfig.v4.ip}/${toString netConfig.v4.prefixLength}" ];
      listenPort = if hostNetConfig.endpoint != null then hostNetConfig.endpoint.port else cfg.port;
      privateKeyFile = "/secrets/wireguard/private/${cfg.netName}";
      generatePrivateKeyFile = true;
    };

    systemd.network.wait-online.ignoredInterfaces = [ interface ];

    networking.firewall.allowedUDPPorts =
      if hostNetConfig.endpoint != null then [ hostNetConfig.endpoint.port ] else [ cfg.port ];

    services.wgautomesh = {
      enable = true;
      gossipSecretFile = config.sops.secrets."wgautomesh/gossip-secret".path;
      openFirewall = true;
      settings = {
        inherit interface;
        peers = pipe netConfig.hosts [
          (filterAttrs (peerHostName: _: peerHostName != hostName))
          (mapAttrsToList (
            _: peerConfig: {
              address = peerConfig.v4.ip;
              endpoint =
                if (peerConfig.endpoint != null) then
                  let
                    inherit (peerConfig.endpoint) fqdn port;
                  in
                  "${fqdn}:${toString port}"
                else
                  null;
              pubkey = peerConfig.publicKey;
            }
          ))
        ];
      };
    };
    systemd.services.wgautomesh = {
      requires = wgService;
      after = wgService;
    };
  };
}
