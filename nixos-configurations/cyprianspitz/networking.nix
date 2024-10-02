{ config, pkgs, ... }:

let
  meta = config.qois.meta;
in
{
  networking.hostName = meta.hosts.cyprianspitz.hostName;

  imports = [ ../../defaults/backplane-net ];

  networking.useDHCP = false;
  networking.interfaces.enp0s31f6.useDHCP = true;
  networking.interfaces.enp2s0.useDHCP = true;

  # Virtualization
  networking.interfaces.vms-nat.useDHCP = false;
  networking.interfaces.vms-nat.ipv4.addresses = [
    (
      let
        netConfig = meta.network.virtual.cyprianspitz-vms-nat;
      in
      {
        address = netConfig.hosts.cyprianspitz.v4.ip;
        prefixLength = netConfig.v4.prefixLength;
      }
    )
  ];

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
      resolveLocalQueries = false;
      settings = {
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
  boot.initrd.network.udhcpc.enable = true;

  services.qois.luks-ssh = {
    enable = true;
    interface = "eth0";
    sshPort = 2222;
    sshHostKey = "/secrets/system/initrd-ssh-key";
    # TODO Solve sops dependency porblem: config.sops.secrets."system/initrd-ssh-key".path;
  };

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
