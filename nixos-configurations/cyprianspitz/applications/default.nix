{
  config,
  pkgs,
  lib,
  ...
}:
{

  imports = [
    ./backup.nix
    ./vpn.nix
  ];

  qois.loadbalancer.enable = true;
  qois.backplane-net.hosts.loadbalancers = lib.mkForce [ "cyprianspitz" ];
}
