{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption;
  inherit (lib.types) path str;
  cfg = config.qois.alertmanager;
  routePrefix = "/alertmanager";
in
{
  options.qois.alertmanager = {
    enable = mkEnableOption "alertmanager email alerting";

    emailTo = mkOption {
      type = str;
      default = "sysadmin@qo.is";
      description = "Address alerts are sent to.";
    };

    msmtpPasswordFile = mkOption {
      type = path;
      description = "Path to the msmtp password file.";
      default = config.sops.secrets."msmtp/password".path;
    };
  };

  config = mkIf cfg.enable {
    services.prometheus.alertmanager = {
      enable = true;
      listenAddress = "127.0.0.1";
      webExternalUrl = "https://${config.qois.prometheus.domain}${routePrefix}/";
      configuration = {
        global = {
          smtp_smarthost = "mail.cyon.ch:587";
          smtp_from = "monitoring@qo.is";
          smtp_auth_username = "system@qo.is";
          smtp_auth_password_file = cfg.msmtpPasswordFile;
          smtp_require_tls = true;
        };
        route = {
          receiver = "email";
          group_by = [
            "alertname"
            "host"
          ];
          group_wait = "30s";
          group_interval = "5m";
          repeat_interval = "4h";
        };
        receivers = [
          {
            name = "email";
            email_configs = [ { to = cfg.emailTo; } ];
          }
        ];
      };
    };

    users.groups.postdrop = { };
    systemd.services.alertmanager.serviceConfig.SupplementaryGroups = [ "postdrop" ];

    services.prometheus.alertmanagers = [
      {
        path_prefix = routePrefix;
        static_configs = [
          { targets = [ "localhost:${toString config.services.prometheus.alertmanager.port}" ]; }
        ];
      }
    ];

    # systemd forgets exit timestamps on reboot, max_over_time keeps the last success visible.
    srvos.prometheus.ruleGroups.qoisPeriodicJobs.alertRules.PeriodicJobNotSucceeded = {
      expr = "systemd_job_success unless on(host, name) (time() - max_over_time(systemd_job_last_success_timestamp[30h]) < 30 * 3600)";
      for = "1h";
      annotations.description = "{{$labels.host}}: {{$labels.name}} has not exited successfully in the last 30h";
    };
  };
}
