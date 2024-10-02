{
  self,
  system,
  pkgs,
  ...
}:
with pkgs.lib;
let
  nixosConfigs = mapAttrsToList (n: v: v.config.system.build.toplevel) self.nixosConfigurations;
in
pkgs.linkFarmFromDrvs "allHosts" (nixosConfigs ++ [ self.packages.${system}.docs ])
