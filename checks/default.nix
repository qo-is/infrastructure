{
  self,
  inputSubsetForNixosConfigurations,
  system,
  pkgs,
  deployPkgs,
  treefmt-nix,
  flakeSelfSpecialUsage,
  ...
}@inputs:
{
  ${system} = {
    formatting = (treefmt-nix.lib.evalModule pkgs ../treefmt.nix).config.build.check flakeSelfSpecialUsage;

    nixos-modules = pkgs.callPackage ./nixos-modules {
      defaultModule = self.nixosModules.default;
      inherit inputSubsetForNixosConfigurations;
      inherit (self.lib) getSubDirs isFolderWithFile;
    };

    nixos-configurations = import ./nixos-configurations inputs;

    # Import deploy-rs tests
  }
  // (deployPkgs.deploy-rs.lib.deployChecks self.deploy);
}
