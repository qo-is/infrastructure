{ lib, ... }:
{
  nodes.server =
    {
      config,
      pkgs,
      ...
    }:
    {
      qois.telegraf.enable = lib.mkForce true;
      services.telegraf.extraConfig.agent.interval = lib.mkForce "50ms";
      # Drop the host-level inputs of the telegraf module and srvos; only the inputs the
      # modules under test contribute are relevant here.
      services.telegraf.extraConfig.inputs = lib.mkForce config.qois.telegraf.serviceInputs;

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
