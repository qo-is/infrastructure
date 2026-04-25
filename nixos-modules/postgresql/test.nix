{ pkgs, lib, ... }:
{
  nodes.server =
    { ... }:
    {
      qois.telegraf.enable = true;
      services.telegraf.extraConfig.agent.interval = lib.mkForce "50ms";

      services.postgresql.enable = true;
      qois.postgresql.package = pkgs.postgresql;
    };
}
