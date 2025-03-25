{ self, pkgs, ... }:
pkgs.linkFarmFromDrvs "all" (
  pkgs.lib.mapAttrsToList (_n: v: v.config.system.build.toplevel) self.nixosConfigurations
)
