{
  deployPkgs,
  pkgs,
  self,
  system,
  ...
}:
{
  nodes = pkgs.lib.mapAttrs (host: config: {
    hostname = "${host}.backplane.net.qo.is";
    profiles.system = {
      sshUser = "root";
      user = "root";
      activationTimeout = 420;
      confirmTimeout = 120;

      path = deployPkgs.deploy-rs.lib.activate.nixos config;
    };
  }) self.nixosConfigurations;
}
