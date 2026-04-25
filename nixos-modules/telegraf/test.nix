{ lib, ... }:
let
  inherit (lib) mkForce;
in
{
  nodes.server =
    { ... }:
    {
      qois.telegraf.enable = true;
      qois.telegraf.monitoring = {
        enable = true;
        ping = [ "127.0.0.1" ];
        pingInterval = "100ms";
        http_response = [
          {
            urls = [ "http://localhost" ];
            response_string_match = "H1ll0 W0rld!";
          }
        ];
      };

      services.nginx.enable = true;
      services.nginx.virtualHosts.localhost.locations."/" = {
        return = "200 'H1ll0 W0rld!'";
      };

      services.telegraf.extraConfig.agent.interval = mkForce "50ms";
    };
}
