{ config, ... }:
{
  qois.nixpkgs-cache = {
    enable = true;
    dnsResolvers = [ config.qois.meta.network.virtual.lindberg-vms-nat.hosts.lindberg.v4.ip ];
  };
}
