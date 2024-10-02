{ config, pkgs, ... }:

{

  networking.hostName = config.qois.meta.hosts.lindberg-webapps.hostName;
  networking.useDHCP = false;
  networking.interfaces.enp1s0.useDHCP = true;

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
