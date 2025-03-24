{
  self,
  system,
  pkgs,
  deployPkgs,
  ...
}:
{
  ${system} = {

    # Check project formatting
    format = pkgs.runCommand "nixfmt-check" { } ''
      set -euo pipefail
      cd ${self}
      ${self.formatter.${system}}/bin/formatter . --check
      mkdir $out
    '';

    nixos-modules = pkgs.callPackage ./nixos-modules {
      inherit (self.lib) getSubDirs isFolderWithFile;
    };

    #TODO(#29): Integration/System tests

    # Import deploy-rs tests
  } // (deployPkgs.deploy-rs.lib.deployChecks self.deploy);
}
