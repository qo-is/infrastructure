{ lib, ... }:
{
  nodes.server =
    { ... }:
    {
      qois.telegraf.enable = true;
      services.telegraf.extraConfig.agent.interval = lib.mkForce "50ms";
    };
}
