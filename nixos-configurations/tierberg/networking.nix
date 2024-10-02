{ config, pkgs, ... }:

let
  meta = config.qois.meta;
  lattenbach-nas-net = meta.network.physical.lattenbach-nas;
in
{
  networking.hostName = meta.hosts.tierberg.hostName;

  imports = [ ../../defaults/backplane-net ];

  networking.enableIPv6 = false; # TODO

  networking.useDHCP = false;
  networking.interfaces.enp1s0.useDHCP = true;
  networking.interfaces.enp2s0.ipv4.addresses = [
    {
      inherit (lattenbach-nas-net.v4) prefixLength;
      address = lattenbach-nas-net.hosts.tierberg.v4.ip;
    }
  ];
  networking.interfaces.enp3s0.useDHCP = true;

  services.qois.luks-ssh = {
    enable = true;
    interface = "eth0";
    sshPort = 2222;
  };
}
