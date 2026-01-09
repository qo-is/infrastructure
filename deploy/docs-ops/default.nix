{
  deployPkgs,
  self,
  system,
  ...
}:
let
  domain = "docs-ops.qo.is";
  sshUser = "nginx-${domain}";
in
{
  nodes.lindberg-webapps.profiles."${domain}" = {
    inherit sshUser;
    path = deployPkgs.deploy-rs.lib.activate.noop self.packages.${system}.docs;
    profilePath = "/var/lib/${sshUser}/.local/state/nix/profiles/webroot";
    remoteBuild = true; # Required because it's a unpriviledged nix user
  };
}
