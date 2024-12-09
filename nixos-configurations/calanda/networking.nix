{ config, pkgs, ... }:

let
  meta = config.qois.meta;
  plessur-dmz-net = meta.network.physical.plessur-dmz;
  plessur-lan-net = meta.network.physical.plessur-lan;
  getCalandaIp4 = net: net.hosts.calanda.v4.ip;
in
{
  networking.hostName = meta.hosts.calanda.hostName;
  networking.domain = "ilanz.fh2.ch";
  networking.enableIPv6 = false; # TODO

  networking.useDHCP = false;
  networking.interfaces.enp4s0.useDHCP = true;

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  networking.interfaces.enp3s0 = {
    ipv4.addresses = [
      {
        inherit (plessur-dmz-net.v4) prefixLength;
        address = getCalandaIp4 plessur-dmz-net;
      }
    ];
  };

  qois.backplane-net.enable = true;

  # TODO: Metaize ips
  services.qois.router = {
    enable = true;
    wanInterface = "enp4s0";
    wirelessInterfaces = [ "wlp5s0" ];
    lanInterfaces = [ "enp2s0" ];
    internalRouterIP = getCalandaIp4 plessur-lan-net;
    dhcp = {
      enable = true;
      localDomain = "ilanz.fh2.ch"; # TODO: Legacy hostname
      dhcpRange = "10.1.1.2,10.1.1.249";
    };
    recursiveDns = {
      enable = true;
      networkIdIp = plessur-lan-net.v4.id;
    };
    wireless = {
      enable = true;
      wleInterface24Ghz = "wlp5s0";
      ssid = "hauser";
    };
  };

  # DMZ
  services.unbound.settings.server = {
    interface = [ plessur-dmz-net.hosts.calanda.v4.ip ];
    access-control = [
      ''"${plessur-dmz-net.v4.id}/${toString plessur-dmz-net.v4.prefixLength}" allow''
    ];
  };
  networking.firewall.interfaces.enp3s0.allowedUDPPorts = [ 53 ];
  networking.nat.internalInterfaces = [ "enp3s0" ];

  # DMZ Portforwarding
  networking.nat.forwardPorts =
    let
      cyprianspitzPort = (
        proto: port: {
          destination = "10.1.1.11:${toString port}";
          proto = proto;
          sourcePort = port;
          loopbackIPs = [ "85.195.200.253" ];
        }
      );
    in
    [
      {
        destination = "10.1.1.11:2222";
        proto = "tcp";
        sourcePort = 8223;
      }
    ]
    ++ map (cyprianspitzPort "tcp") [
      80
      443
    ]
    ++ map (cyprianspitzPort "udp") [
      51824
      1666
      41641
      3478
      3479
    ];
}
