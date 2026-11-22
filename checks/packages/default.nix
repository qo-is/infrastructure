{
  self,
  pkgs,
  system,
  ...
}:
let
  inherit (pkgs) linkFarmFromDrvs;
  inherit (pkgs.lib) attrValues;
in
linkFarmFromDrvs "all-packages" (attrValues self.packages.${system})
