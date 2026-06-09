{ config, ... }:

let
  meta = config.qois.meta;
  netConfig = meta.network.virtual.lindberg-vms-nat;
  containerNetConfig = meta.network.virtual.lindberg-containers-nat;
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
    {
      address = netConfig.hosts.lindberg.v4.ip;
      prefixLength = netConfig.v4.prefixLength;
    }
  ];

  networking.bridges.vms-nat.interfaces = [ ];
  systemd.network.networks."40-vms-nat" = {
    networkConfig = {
      ConfigureWithoutCarrier = true;
      DHCPServer = true;
    };
    linkConfig.RequiredForOnline = "no-carrier";
    dhcpServerConfig = {
      PoolOffset = 2;
      PoolSize = 252;
      EmitDNS = "yes";
      DNS = netConfig.hosts.lindberg.v4.ip;
    };
    extraConfig = ''
      [Network]
      Domains=${netConfig.domain}

      [DHCPServer]
      EmitDomains=yes
    '';
  };

  networking.nat = {
    enable = true;
    internalInterfaces = [
      "vms-nat"
      "ve-+"
    ];
    internalIPs = [ "${netConfig.v4.id}/${builtins.toString netConfig.v4.prefixLength}" ];
    externalInterface = "enp5s0";
  };

  services.resolved.extraConfig = ''
    DNSStubListenerExtra=${netConfig.hosts.lindberg.v4.ip}
    DNSStubListenerExtra=${containerNetConfig.hosts.lindberg.v4.ip}
  '';

  networking.firewall.interfaces.vms-nat = {
    allowedUDPPorts = [
      53
      67
    ];
    allowedTCPPorts = [ 53 ];
  };

  networking.firewall.interfaces."ve-+" = {
    allowedUDPPorts = [ 53 ];
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
