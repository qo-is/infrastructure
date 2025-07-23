{
  self,
  flakeSelf,
  system,
  pkgs,
  deployPkgs,
  treefmtEval,
  ...
}@inputs:
{
  ${system} = {
    formatting = treefmtEval.config.build.check flakeSelf;

    nixos-modules = pkgs.callPackage ./nixos-modules {
      defaultModule = self.nixosModules.default;
      inherit (self.lib) getSubDirs isFolderWithFile;
    };

    nixos-configurations = import ./nixos-configurations inputs;

    # Import deploy-rs tests
  }
  // (deployPkgs.deploy-rs.lib.deployChecks self.deploy);
}
