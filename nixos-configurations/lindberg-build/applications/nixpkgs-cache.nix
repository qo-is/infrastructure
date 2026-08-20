{ config, ... }:
{
  qois.nixpkgs-cache = {
    # Disabled: unused since the substituter reference to nixpkgs-cache.qo.is
    # was commented out in nixos-modules/system/default.nix. Causes TLS
    # verify errors proxying to cache.nixos.org while running unused.
    enable = false;
    dnsResolvers = [ config.qois.meta.network.virtual.lindberg-vms-nat.hosts.lindberg.v4.ip ];
  };
}
