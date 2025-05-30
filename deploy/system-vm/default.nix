{
  deployPkgs,
  pkgs,
  self,
  ...
}:
let
  inherit (pkgs.lib) pipe filterAttrs mapAttrs;
in
{
  nodes = pipe self.nixosConfigurations [
    (filterAttrs (_n: v: v.config.services.qemuGuest.enable && !v.config.qois.git-ci-runner.enable))
    (mapAttrs (
      host: config: {
        hostname = "${host}.backplane.net.qo.is";
        profiles.system-vm = {
          sshUser = "root";
          user = "root";
          activationTimeout = 300;
          confirmTimeout = 60;
          remoteBuild = true;
          path = deployPkgs.deploy-rs.lib.activate.nixos config;
        };
      }
    ))
  ];
}
