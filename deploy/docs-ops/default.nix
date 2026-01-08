{
  deployPkgs,
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
    profilePath = "/nix/var/nix/profiles/per-user/nginx-${domain}/profile/webroot";
    remoteBuild = true; # Required because it's a unpriviledged nix user
  };
}
