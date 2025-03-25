{ config, ... }:

{

  networking.hostName = config.qois.meta.hosts.lindberg-build.hostName;
  networking.useDHCP = false;
  networking.interfaces.enp11s0.useDHCP = true;

  qois.backplane-net.enable = true;

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
