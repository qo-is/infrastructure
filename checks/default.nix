{
  self,
  system,
  pkgs,
  deployPkgs,
  ...
}@inputs:
{
  ${system} = {

    # TODO: Check project formatting

    nixos-modules = pkgs.callPackage ./nixos-modules {
      inherit (self.lib) getSubDirs isFolderWithFile;
    };

    nixos-configurations = import ./nixos-configurations inputs;

    # Import deploy-rs tests
  } // (deployPkgs.deploy-rs.lib.deployChecks self.deploy);
}
