{ config, pkgs, ... }:

let
  meta = config.qois.meta;
in
{
  networking.hostName = meta.hosts.lindberg.hostName;

  imports = [ ../../defaults/backplane-net ];

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
      resolveLocalQueries = false;
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
  systemd.services.dnsmasq.bindsTo = [ "network-addresses-vms-nat.service" ];
  networking.firewall.interfaces.vms-nat = {
    allowedUDPPorts = [
      53
      67
    ];
    allowedTCPPorts = [ 53 ];
  };

  # Boot
  boot.initrd.network.udhcpc.enable = true;

  services.qois.luks-ssh = {
    enable = true;
    interface = "eth0";
    sshPort = 2222;
  };

  # Use this node as vpn exit node
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
