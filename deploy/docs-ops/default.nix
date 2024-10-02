{
  deployPkgs,
  pkgs,
  self,
  system,
  ...
}:
let
  domain = "docs-ops.qo.is";
in
{
  nodes.lindberg-webapps.profiles."${domain}" = {
    sshUser = "nginx-${domain}";
    path = deployPkgs.deploy-rs.lib.activate.noop self.packages.${system}.docs;
    profilePath = "/var/lib/nginx-${domain}/root";
  };
}
