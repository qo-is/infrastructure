{
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.qois.backplane-net;
in
{
  options.qois.backplane-net = {
    enable = mkEnableOption "Enable backplane server services";
    netName = mkOption {
      description = "Network Name";
      type = types.str;
      default = "backplane";
    };
    port = mkOption {
      description = "Wireguard Default Port";
      type = types.number;
      default = 51825;
    };
  };

  config = lib.mkIf cfg.enable (
    let
      hostName = config.networking.hostName;
      netConfig = config.qois.meta.network.virtual.${cfg.netName};
      hostNetConfig = netConfig.hosts.${hostName};
      interface = "wg-${cfg.netName}";
      wgService = [ "wireguard-${interface}.service" ];
    in
    {
      sops.secrets."wgautomesh/gossip-secret".restartUnits = [ "wgautomesh.service" ];

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

      # Configure wgautomesh to setup peers. Make sure that the name is not used in the VPN module
      services.wgautomesh = {
        enable = true;
        gossipSecretFile = config.sops.secrets."wgautomesh/gossip-secret".path;
        openFirewall = true;
        settings = {
          inherit interface;

          # Map meta network configuration to the format of wgautomesh and filter out peers with endpoints
          peers = pipe netConfig.hosts [
            (filterAttrs (peerHostName: _: peerHostName != hostName)) # Not this host
            (mapAttrsToList (
              _: peerConfig: {
                address = peerConfig.v4.ip;
                endpoint =
                  if (peerConfig.endpoint != null) then
                    with peerConfig.endpoint; "${fqdn}:${toString port}"
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
    }
  );
}
