{ lib, ... }:
let
  inherit (lib) mkForce;
in
{
  nodes.server =
    { ... }:
    {
      qois.telegraf.enable = mkForce true;
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
        buildStatus = [
          {
            owner = "qo.is";
            repo = "infrastructure";
            branch = "main";
          }
        ];
        buildStatusUrl = "http://localhost";
        buildStatusInterval = "100ms";
      };

      services.nginx.enable = true;
      services.nginx.virtualHosts.localhost.locations = {
        "/".return = "200 'H1ll0 W0rld!'";
        "/api/v1/repos/qo.is/infrastructure/commits/main/status".return =
          ''200 '{"state":"pending","sha":"c0ffee","total_count":1}' '';
      };

      services.telegraf.extraConfig.agent.interval = mkForce "50ms";
    };
}
