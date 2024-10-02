{ config, pkgs, ... }:
{
  qois.nixpkgs-cache = {
    enable = true;
    hostname = "nixpkgs-cache.qo.is";
    dnsResolvers = [ config.qois.meta.network.virtual.lindberg-vms-nat.hosts.lindberg.v4.ip ];
  };
}
