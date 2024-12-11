{ config, pkgs, ... }:

let
  meta = config.qois.meta;
  plessur-dmz-net = meta.network.physical.plessur-dmz;
  plessur-lan-net = meta.network.physical.plessur-lan;
  plessur-ext-net = meta.network.physical.plessur-ext;
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

  # Assign the static address to cyprianspitz (required for ssh luks unlock at this time)
  services.dnsmasq.settings.dhcp-host =
    let
      cyprianspitzEnp0s31f6Mac = "9c:6b:00:58:6e:90";
      inherit (plessur-lan-net.hosts.cyprianspitz.v4) ip;
    in
    "${cyprianspitzEnp0s31f6Mac},${ip}";

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
      cyprianspitzPortDst = (
        proto: sourcePort: dstPort: {
          destination = "${plessur-lan-net.hosts.cyprianspitz.v4.ip}:${toString dstPort}";
          inherit proto;
          inherit sourcePort;
          loopbackIPs = [ plessur-ext-net.hosts.calanda.v4.ip ];
        }
      );
      cyprianspitzPort = proto: port: (cyprianspitzPortDst proto port port);
    in
    [
      (cyprianspitzPortDst "tcp" 8222 22)
      (cyprianspitzPortDst "tcp" 8223 2222)
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
