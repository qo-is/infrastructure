{ ... }:
{

  imports = [
    ./loadbalancer.nix
    ./ssh-forwarding.nix
  ];

  qois.telegraf.enable = true;
}
