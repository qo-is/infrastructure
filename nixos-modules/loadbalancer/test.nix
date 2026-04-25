{ lib, ... }:
{
  nodes.server =
    { ... }:
    {
      qois.loadbalancer = {
        enable = true;
        domains = {
          "test.example.com" = "backend";
        };
        hostmap = {
          "backend" = "127.0.0.1";
        };
        extraConfig = "";
      };

      qois.telegraf.enable = true;
      services.telegraf.extraConfig.agent.interval = lib.mkForce "50ms";
    };
}
