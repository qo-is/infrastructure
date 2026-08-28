{
  lib,
  ...
}:
{

  imports = [
    ./backup.nix
    ./dns.nix
    ./vpn.nix
  ];

  qois.loadbalancer.enable = true;
  qois.backplane-net.hosts.loadbalancers = lib.mkForce [ "cyprianspitz" ];
}
