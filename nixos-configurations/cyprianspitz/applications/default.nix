{
  lib,
  ...
}:
{

  imports = [
    ./backup.nix
    ./vpn.nix
  ];

  qois.telegraf.enable = true;
  qois.loadbalancer.enable = true;
  qois.backplane-net.hosts.loadbalancers = lib.mkForce [ "cyprianspitz" ];
}
