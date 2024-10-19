{
  self,
  system,
  pkgs,
  ...
}:
with pkgs.lib;
{
  ${system} =
    let
      packages = pipe (self.lib.foldersWithNix ./.) [
        (map (name: {
          inherit name;
          path = path.append ./. "./${name}/default.nix";
        }))
        (map (
          { name, path }:
          {
            inherit name;
            value = pkgs.callPackage path {
              inherit self;
              inherit system;
            };
          }
        ))
        listToAttrs
      ];
    in
    packages
    // {
      default =
        let
          nixosConfigs = mapAttrsToList (n: v: v.config.system.build.toplevel) self.nixosConfigurations;
        in
        pkgs.linkFarmFromDrvs "all" (nixosConfigs ++ (attrValues packages));
    };
}
