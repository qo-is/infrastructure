{ lib, ... }:
{
  nodes.server =
    { pkgs, ... }:
    {
      qois.telegraf.enable = lib.mkForce true;
      services.telegraf.extraConfig.agent.interval = lib.mkForce "50ms";
      # Only the postgresql input is needed for this test; keep in sync with
      # nixos-modules/postgresql/default.nix's services.telegraf.extraConfig.inputs.postgresql.
      services.telegraf.extraConfig.inputs = lib.mkForce {
        postgresql = [
          { address = "host=/run/postgresql user=telegraf dbname=postgres sslmode=disable"; }
        ];
      };

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
