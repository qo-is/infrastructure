{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.qois.git;
in
with lib;
{
  options.qois.git = {
    enable = mkEnableOption "Enable qois git service";

    domain = mkOption {
      type = types.str;
      default = "git.qo.is";
      description = "Domain, under which the service is served.";
    };
  };

  config = mkIf cfg.enable {
    qois.postgresql.enable = true;

    services.forgejo = {
      enable = true;
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
        service.DISABLE_REGISTRATION = true;
        mailer = {
          ENABLED = true;
          PROTOCOL = "sendmail";
          FROM = "git@qo.is";
          SENDMAIL_PATH = "${pkgs.msmtp}/bin/sendmail";
          # Note: The sendmail passwordeval has to use the coreutil cat (that is in the services path)
          #       instead of the busybox one due to filtered syscalls.
          SENDMAIL_ARGS = "--passwordeval 'cat ${config.sops.secrets."msmtp/password".path}'";
        };
        log.LEVEL = "Warn";
      };
    };

    qois.backup-client.includePaths = [ config.services.forgejo.stateDir ];

    users.users.forgejo.extraGroups = [ "postdrop" ];
    systemd.services.forgejo.serviceConfig.ReadOnlyPaths = [
      config.sops.secrets."msmtp/password".path
    ];

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
        locations."/" = {
          proxyPass = "http://unix:${config.services.forgejo.settings.server.HTTP_ADDR}";
          proxyWebsockets = true;
        };
      };
    };
  };
}
