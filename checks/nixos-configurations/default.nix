{ self, pkgs, ... }:
pkgs.linkFarmFromDrvs "all" (
  pkgs.lib.mapAttrsToList (n: v: v.config.system.build.toplevel) self.nixosConfigurations
)
