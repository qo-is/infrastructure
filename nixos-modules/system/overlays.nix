{
  config,
  lib,
  pkgs,
  options,
  ...
}:

{
  nix.nixPath = options.nix.nixPath.default;
}
