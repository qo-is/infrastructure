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
          {
            owner = "qo.is";
            repo = "infrastructure";
            branch = "green";
          }
        ];
        buildStatusUrl = "http://localhost";
        buildStatusInterval = "100ms";
      };

      qois.telegraf.periodicJobs = [
        "demo-job.service"
        "failing-job.service"
      ];
      systemd.services.demo-job = {
        serviceConfig.Type = "oneshot";
        script = "true";
        # Like real backups: the timer keeps the unit loaded, so systemd retains its exit state.
        startAt = "2099-01-01";
      };
      systemd.services.failing-job = {
        serviceConfig.Type = "oneshot";
        script = "false";
        startAt = "2099-01-01";
      };

      services.nginx.enable = true;
      services.nginx.virtualHosts.localhost.locations = {
        "/".return = "200 'H1ll0 W0rld!'";
        "/api/v1/repos/qo.is/infrastructure/commits/main/status".return =
          ''200 '{"state":"pending","sha":"c0ffee","total_count":1}' '';
        "/api/v1/repos/qo.is/infrastructure/commits/green/status".return =
          ''200 '{"state":"success","sha":"beef","total_count":2,"statuses":[{"updated_at":"2026-10-08T18:11:20Z"},{"updated_at":"2026-10-08T18:17:53Z"}]}' '';
      };

      services.telegraf.extraConfig.agent.interval = mkForce "50ms";
    };
}
