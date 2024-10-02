{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hosts.nix
    ./network-physical.nix
    ./network-virtual.nix
  ];
}
