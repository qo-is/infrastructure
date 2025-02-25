{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.qois.vault;
in
with lib;
{
  options.qois.vault = {
    enable = mkEnableOption "Enable qois vault service";

    domain = mkOption {
      type = types.str;
      default = "vault.qo.is";
      description = "Domain, under which the service is served.";
    };
  };

  config = mkIf cfg.enable {

    services.vaultwarden = {
      enable = true;
      dbBackend = "postgresql";
      environmentFile = config.sops.secrets."vaultwarden/environment-file".path;
      config = {
        DATA_FOLDER = "/var/lib/bitwarden_rs";
        DATABASE_URL = "postgresql:///vaultwarden";

        DOMAIN = "https://${cfg.domain}";
        ROCKET_PORT = 8222;

        USE_SENDMAIL = true;
        SENDMAIL_COMMAND = "${pkgs.msmtp}/bin/sendmail";

        SMTP_FROM = "vault@qo.is";
        SMTP_FROM_NAME = cfg.domain;

        SIGNUPS_ALLOWED = false;
        INVITATIONS_ALLOWED = false;
        SIGNUPS_DOMAINS_WHITELIST = "qo.is";
        SIGNUPS_VERIFY = true;

        EXPERIMENTAL_CLIENT_FEATURE_FLAGS = "fido2-vault-credentials";
        SHOW_PASSWORD_HINT = false;
        TRASH_AUTO_DELETE_DAYS = 30;
      };
    };

    qois.backup-client.includePaths = [ config.services.vaultwarden.config.DATA_FOLDER ];

    services.postgresql =
      let
        name = config.users.users.vaultwarden.name;
      in
      {
        enable = true;
        ensureUsers = [
          {
            inherit name;
            ensureDBOwnership = true;
          }
        ];
        ensureDatabases = [ name ];
      };

    # See https://search.nixos.org/options?channel=unstable&show=services.vaultwarden.environmentFile
    sops.secrets."vaultwarden/environment-file".restartUnits = [ "vaultwarden.service" ];

    users.users.vaultwarden.extraGroups = [ "postdrop" ];

    networking.hosts."127.0.0.1" = [ cfg.domain ];
    services.nginx = {
      enable = true;

      virtualHosts.${cfg.domain} = {
        kTLS = true;
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString config.services.vaultwarden.config.ROCKET_PORT}";
          proxyWebsockets = true;
        };
      };
    };
  };
}
