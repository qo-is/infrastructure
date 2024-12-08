{
  pkgs,
  lib,
  config,
  ...
}:
let
  hostName = config.networking.hostName;
  netName = "backplane";
  netConfig = config.qois.meta.network.virtual.${netName};
  hostNetConfig = netConfig.hosts.${hostName};
  wgDefaultPort = 51825;
in
{
  sops.secrets."wgautomesh/gossip-secret".restartUnits = [ "wgautomesh.service" ];

  networking.wireguard.enable = true;
  networking.wireguard.interfaces."wg-${netName}" = {
    ips = [ "${hostNetConfig.v4.ip}/${builtins.toString netConfig.v4.prefixLength}" ];
    listenPort = if hostNetConfig.endpoint != null then hostNetConfig.endpoint.port else wgDefaultPort;
    privateKeyFile = "/secrets/wireguard/private/${netName}";
    generatePrivateKeyFile = true;
  };

  systemd.network.wait-online.ignoredInterfaces = [ "wg-${netName}" ];

  networking.firewall.allowedUDPPorts =
    if hostNetConfig.endpoint != null then [ hostNetConfig.endpoint.port ] else [ wgDefaultPort ];

  # Configure wgautomesh to setup peers. Make sure that the name is not used in the VPN module
  services.wgautomesh = {
    enable = true;
    gossipSecretFile = builtins.toString config.sops.secrets."wgautomesh/gossip-secret".path;
    openFirewall = true;
    logLevel = "info";
    settings = {
      interface = "wg-${netName}";

      # Map meta network configuration to the format of wgautomesh and filter out peers with endpoints
      peers =
        let
          reachableHosts = lib.filterAttrs (
            peerHostName: peerConfig: peerHostName != hostName # Not this host
          ) netConfig.hosts;
        in
        lib.mapAttrsToList (_: peerConfig: {
          address = peerConfig.v4.ip;
          endpoint =
            if peerConfig.endpoint != null then
              with peerConfig.endpoint; "${fqdn}:${builtins.toString port}"
            else
              null;
          pubkey = peerConfig.publicKey;
        }) reachableHosts;
    };
  };
  systemd.services.wgautomesh =
    let
      wgInterface = [ "wireguard-wg-backplane.service" ];
    in
    {
      requires = wgInterface;
      after = wgInterface;
    };
}
