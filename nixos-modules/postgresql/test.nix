{ lib, ... }:
{
  nodes.server =
    { pkgs, ... }:
    {
      qois.telegraf.enable = true;
      services.telegraf.extraConfig.agent.interval = lib.mkForce "50ms";

      sops.secrets = lib.mkForce { };

      services.postgresql.enable = true;
      services.postgresql.initdbArgs = [ "--data-checksums" ];
      qois.postgresql.package = pkgs.postgresql_14;

      specialisation.upgraded.configuration = {
        qois.postgresql.package = lib.mkForce pkgs.postgresql_18;
        qois.postgresql.upgradeFrom = lib.mkForce pkgs.postgresql_14;
      };
    };
}
