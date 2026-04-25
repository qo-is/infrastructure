{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf mkOption;
  inherit (lib.types) path str;
  cfg = config.qois.git;
in
{
  options.qois.git = {
    enable = mkEnableOption "Enable qois git service";

    domain = mkOption {
      type = str;
      default = "git.qo.is";
      description = "Domain, under which the service is served.";
    };

    msmtpPasswordFile =
      mkOption {
        type = path;
        description = "Path to the msmtp password file.";
      }
      // (
        if config.sops.secrets ? "msmtp/password" then
          { default = config.sops.secrets."msmtp/password".path; }
        else
          { }
      );
  };

  config = mkIf cfg.enable {
    services.postgresql.enable = true;

    services.forgejo = {
      enable = true;
      package = pkgs.forgejo;
      database.type = "postgres";

      lfs.enable = true;

      settings = {
        DEFAULT.APP_NAME = cfg.domain;
        server = {
          DOMAIN = cfg.domain;
          ROOT_URL = "https://${cfg.domain}";
          PROTOCOL = "http+unix";
          DISABLE_SSH = true;
        };
        "ssh.minimum_key_sizes".RSA = 2047;
        session.COOKIE_SECURE = true;
        service = {
          DISABLE_REGISTRATION = true;
          ENABLE_NOTIFY_MAIL = true;
          DEFAULT_KEEP_EMAIL_PRIVATE = true;
        };
        mailer = {
          ENABLED = true;
          PROTOCOL = "sendmail";
          FROM = "git@qo.is";
          SENDMAIL_PATH = "${pkgs.msmtp}/bin/sendmail";
          # Note: The sendmail passwordeval has to use the coreutil cat (that is in the services path)
          #       instead of the busybox one due to filtered syscalls.
          SENDMAIL_ARGS = "--passwordeval 'cat ${cfg.msmtpPasswordFile}' --";
        };
        log.LEVEL = "Warn";
        metrics.ENABLED = true;
      };
    };

    qois.backup-client.includePaths = [ config.services.forgejo.stateDir ];

    users.users.forgejo.extraGroups = [ "postdrop" ];
    systemd.services.forgejo.serviceConfig.ReadOnlyPaths = [
      cfg.msmtpPasswordFile
    ];

    services.telegraf.extraConfig.inputs = {
      prometheus = [
        {
          urls = [ "https://${cfg.domain}/metrics" ];
          metric_version = 2;
        }
      ];
      x509_cert = [
        { sources = [ "https://${cfg.domain}:443" ]; }
      ];
    };

    networking.hosts."127.0.0.1" = [ cfg.domain ];
    services.nginx = {
      enable = true;

      virtualHosts.${cfg.domain} = {
        kTLS = true;
        forceSSL = true;
        enableACME = true;
        extraConfig = ''
          client_max_body_size 512M;
        '';
        locations."/metrics" = {
          extraConfig = ''
            allow 127.0.0.1/24;
            allow 10.250.0.0/24;
            deny all;
          '';
          proxyPass = "http://unix:${config.services.forgejo.settings.server.HTTP_ADDR}";
        };
        locations."/" = {
          proxyPass = "http://unix:${config.services.forgejo.settings.server.HTTP_ADDR}";
          proxyWebsockets = true;
        };
      };
    };
  };
}
