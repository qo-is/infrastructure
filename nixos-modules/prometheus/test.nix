{ lib, ... }:
{
  # Note: This extends the default configuration from ${self}/checks/nixos-modules
  nodes.server =
    { ... }:
    {
      qois.prometheus.enable = true;
      qois.telegraf.enable = true;
      services.telegraf.extraConfig.agent.interval = lib.mkForce "50ms";
    };
}
