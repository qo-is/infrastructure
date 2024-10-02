{
  config,
  lib,
  pkgs,
  options,
  ...
}:
{
  imports = [
    ./hosts.nix
    ./network.nix
  ];
}
