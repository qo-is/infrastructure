{
  config,
  lib,
  pkgs,
  options,
  ...
}:

{
  nixpkgs.overlays = [ (import ../../overlays) ];
  nix.nixPath = options.nix.nixPath.default;
}
