{ self, pkgs, ... }:
let
  inherit (pkgs.lib) attrValues;
in
pkgs.linkFarmFromDrvs "all" (attrValues self.packages)
