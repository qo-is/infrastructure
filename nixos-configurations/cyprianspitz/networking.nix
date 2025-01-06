{ config, pkgs, ... }:

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
  networking.interfaces = {
    # enp0s31f6: 1 Gbit mainboard interface
    enp0s31f6.ipv4.addresses = [
      (getNetV4Ip meta.network.physical.plessur-lan)
    ];

    # wlp0s20f3: Mainboard Wireless interface
    # enp3s0: 2.5 Gbit mainboard interface: Connected to ether1
    #enp3s0.useDHCP = true;

    # enp1s0f0: mikrotik sfp28-1: ether-pcie1 passthrough
    enp1s0f0.useDHCP = true;
    # enp1s0f1: mikrotik sfp28-2: ether-pcie2 passthrough
    enp1s0f1.useDHCP = true;
    # enp1s0f2: mikrotik ether1/bridge1: ether-pcie3 bridge \
    enp1s0f2.useDHCP = true;
    # enp1s0f3: mikrotik ether1/bridge1: ether-pcie4 bridge  > connected to enp3s0
    enp1s0f3.useDHCP = true;
  };

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
  services.qois.luks-ssh = {
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
