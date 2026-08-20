{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf mkOption;
  inherit (lib.types) path str;
  cfg = config.qois.alertmanager;
in
{
  options.qois.alertmanager = {
    enable = mkEnableOption "alertmanager email alerting";

    emailTo = mkOption {
      type = str;
      default = "spam.qois-alerts@fh2.ch";
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
        static_configs = [
          { targets = [ "localhost:${toString config.services.prometheus.alertmanager.port}" ]; }
        ];
      }
    ];
  };
}
