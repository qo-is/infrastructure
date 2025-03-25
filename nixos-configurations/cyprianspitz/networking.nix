{ config, ... }:

let
  meta = config.qois.meta;
  getNetV4Ip = net: {
    address = net.hosts.cyprianspitz.v4.ip;
    prefixLength = net.v4.prefixLength;
  };
  calandaIp = meta.network.physical.plessur-lan.hosts.calanda.v4.ip;
in
{
  networking.enableIPv6 = false;
  networking.hostName = meta.hosts.cyprianspitz.hostName;

  networking.nameservers = [ calandaIp ];
  networking.useDHCP = false;
  networking.interfaces.enp0s31f6.ipv4.addresses = [
    (getNetV4Ip meta.network.physical.plessur-lan)
  ];

  networking.defaultGateway = {
    address = calandaIp;
    interface = "enp0s31f6";
  };

  # Virtualization
  networking.interfaces.vms-nat = {
    useDHCP = false;
    ipv4.addresses = [
      (getNetV4Ip meta.network.virtual.cyprianspitz-vms-nat)
    ];
  };

  networking.bridges.vms-nat.interfaces = [ ];
  networking.nat = {
    enable = true;
    internalInterfaces = [ "vms-nat" ];
    internalIPs = with meta.network.virtual.cyprianspitz-vms-nat.v4; [
      "${id}/${builtins.toString prefixLength}"
    ];
    externalInterface = "enp0s31f6";
  };
  services.dnsmasq =
    let
      netConfig = meta.network.virtual.cyprianspitz-vms-nat;
    in
    {
      enable = true;
      resolveLocalQueries = true;
      settings = {
        server = [ calandaIp ];
        interface = "vms-nat";
        bind-interfaces = true;

        domain-needed = true;

        domain = netConfig.domain;
        dhcp-range = [ "10.248.0.2,10.248.0.253" ];
        dhcp-option = [
          "option:router,${netConfig.hosts.cyprianspitz.v4.ip}"
          "option:domain-search,${netConfig.domain}"
        ];
        dhcp-authoritative = true;
      };
    };
  systemd.services.dnsmasq.bindsTo = [ "network-addresses-vms-nat.service" ];
  networking.firewall.interfaces.vms-nat = {
    allowedUDPPorts = [
      53
      67
    ];
    allowedTCPPorts = [ 53 ];
  };

  # Boot
  qois.luks-ssh = {
    enable = true;
    interface = "eth0";

    sshPort = 2222;
    sshHostKey = "/secrets/system/initrd-ssh-key";
    # TODO Solve sops dependency porblem: config.sops.secrets."system/initrd-ssh-key".path;
  };

  qois.backplane-net.enable = true;

  # Configure this node to be used as an vpn exit node
  qois.vpn-exit-node.enable = true;
}
