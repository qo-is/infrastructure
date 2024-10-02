{ config, pkgs, ... }:
let
  meta = config.qois.meta;
  plessur-dmz-net = meta.network.physical.plessur-dmz;
  getCalandaIp4 = net: net.hosts.calanda.v4.ip;
in
{
  networking.hostName = meta.hosts.fulberg.hostName;

  imports = [ ../../defaults/backplane-net ];

  # WWAN is currently not available due to a broken SIM-card.
  #services.qois.wwan = {
  #  enable = true;
  #  apn = "gprs.swisscom.ch";
  #  networkInterface = "wwp0s19u1u3i12";
  #};

  networking.interfaces.enp1s0 = {
    useDHCP = false;
    ipv4.addresses = [
      {
        inherit (plessur-dmz-net.v4) prefixLength;
        address = plessur-dmz-net.hosts.fulberg.v4.ip;
      }
    ];
  };

  networking.defaultGateway = plessur-dmz-net.v4.gateway;
  networking.nameservers = plessur-dmz-net.v4.nameservers;

  # Configure this node to be used as an vpn exit node
  qois.backup-client.includePaths = [ "/var/lib/tailscale" ];
  services.tailscale = {
    enable = true;
    openFirewall = true;
    useRoutingFeatures = "server";
    authKeyFile = config.sops.secrets."tailscale/key".path;
    extraUpFlags = [
      "--login-server=https://vpn.qo.is"
      "--advertise-exit-node"
      (
        with meta.network.virtual.backplane.v4; "--advertise-routes=${id}/${builtins.toString prefixLength}"
      )
      "--advertise-tags=tag:srv"
    ];
  };
}
