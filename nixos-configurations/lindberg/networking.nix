{ config, ... }:

let
  meta = config.qois.meta;
in
{
  qois.networkd.enable = true;

  networking.hostName = meta.hosts.lindberg.hostName;
  networking.enableIPv6 = false; # TODO(#5): Enable ipv6

  networking.useDHCP = false;
  networking.interfaces.enp5s0.useDHCP = true;

  # Virtualization
  networking.interfaces.vms-nat.useDHCP = false;
  networking.interfaces.vms-nat.ipv4.addresses = [
    (
      let
        netConfig = meta.network.virtual.lindberg-vms-nat;
      in
      {
        address = netConfig.hosts.lindberg.v4.ip;
        prefixLength = netConfig.v4.prefixLength;
      }
    )
  ];

  networking.bridges.vms-nat.interfaces = [ ];
  systemd.network.networks."40-vms-nat" = {
    networkConfig.ConfigureWithoutCarrier = true;
    linkConfig.RequiredForOnline = "no-carrier";
  };
  networking.nat = {
    enable = true;
    internalInterfaces = [ "vms-nat" ];
    internalIPs = with meta.network.virtual.lindberg-vms-nat.v4; [
      "${id}/${builtins.toString prefixLength}"
    ];
    externalInterface = "enp5s0";
  };
  services.dnsmasq =
    let
      netConfig = meta.network.virtual.lindberg-vms-nat;
    in
    {
      enable = true;
      resolveLocalQueries = true;
      settings = {
        interface = "vms-nat";
        bind-interfaces = true;

        domain-needed = true;

        domain = netConfig.domain;
        dhcp-range = [ "10.247.0.2,10.247.0.253" ];
        dhcp-option = [
          "option:router,${netConfig.hosts.lindberg.v4.ip}"
          "option:domain-search,${netConfig.domain}"
        ];
        dhcp-authoritative = true;
      };
    };
  systemd.services.dnsmasq = {
    requires = [ "systemd-networkd-wait-online@vms-nat.service" ];
    after = [ "systemd-networkd-wait-online@vms-nat.service" ];
  };
  networking.firewall.interfaces.vms-nat = {
    allowedUDPPorts = [
      53
      67
    ];
    allowedTCPPorts = [ 53 ];
  };

  # Boot
  boot.initrd.network.udhcpc.enable = true;

  qois.luks-ssh = {
    enable = true;
    interface = "eth0";
    sshPort = 2222;
  };

  qois.backplane-net.enable = true;

  qois.vpn-exit-node.enable = true;
}
