{
  deployPkgs,
  self,
  system,
  ...
}:
let
  domain = "docs-ops.qo.is";
  user = "nginx-${domain}";
in
{
  nodes.lindberg-webapps.profiles."${domain}" = {
    sshUser = user;
    path = deployPkgs.deploy-rs.lib.activate.noop self.packages.${system}.docs;
    profilePath = "/nix/var/nix/profiles/per-user/${user}/webroot";
    remoteBuild = true; # Required because it's a unpriviledged nix user
  };
}
