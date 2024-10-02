{
  self,
  system,
  pkgs,
  deployPkgs,
  ...
}@inputs:
{
  ${system} = {

    # Check project formatting
    format = pkgs.runCommand "nixfmt-check" { } ''
      set -euo pipefail
      cd ${self}
      ${self.formatter.${system}}/bin/formatter . --check
      mkdir $out
    '';

    #TODO(#29): Integration/System tests

    # Import deploy-rs tests
  } // (deployPkgs.deploy-rs.lib.deployChecks self.deploy);
}
