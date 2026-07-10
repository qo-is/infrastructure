{
  config,
  options,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf mkOption;
  inherit (lib.types) str;
  cfg = config.qois.vault;
in
{
  options.qois.vault = {
    enable = mkEnableOption "Enable qois vault service";

    domain = mkOption {
      type = str;
      default = "vault.qo.is";
      description = "Domain, under which the service is served.";
    };

    environmentFile =
      options.services.vaultwarden.environmentFile
      // (
        if config.sops.secrets ? "vaultwarden/environment-file" then
          {
            default = config.sops.secrets."vaultwarden/environment-file".path;
          }
        else
          { }
      );
  };

  config = mkIf cfg.enable {

    services.vaultwarden = {
      enable = true;
      dbBackend = "postgresql";

      inherit (cfg) environmentFile domain;
      configureNginx = true;
      configurePostgres = true;

      config = {
        DATA_FOLDER = "/var/lib/vaultwarden";

        USE_SENDMAIL = true;
        SENDMAIL_COMMAND = "${pkgs.msmtp}/bin/sendmail";

        ## Enable this to bypass the admin panel security. This option is only
        ## meant to be used with the use of a separate auth layer in front
        # DISABLE_ADMIN_TOKEN=false

        SMTP_FROM = "vault@qo.is";
        SMTP_FROM_NAME = cfg.domain;

        SIGNUPS_ALLOWED = false;
        INVITATIONS_ALLOWED = false;
        SIGNUPS_DOMAINS_WHITELIST = "qo.is";
        SIGNUPS_VERIFY = true;
        EMAIL_CHANGE_ALLOWED = false;

        # TODO: push notifications, see https://github.com/dani-garcia/vaultwarden/blob/1.36.0/.env.template#L112

        EXPERIMENTAL_CLIENT_FEATURE_FLAGS = "fido2-vault-credentials";
        SHOW_PASSWORD_HINT = false;
        TRASH_AUTO_DELETE_DAYS = 30;
      };
    };

    qois.backup-client.includePaths = [ config.services.vaultwarden.config.DATA_FOLDER ];

    # See https://search.nixos.org/options?channel=unstable&show=services.vaultwarden.environmentFile
    sops.secrets."vaultwarden/environment-file".restartUnits = [ "vaultwarden.service" ];

    users.users.vaultwarden.extraGroups = [ "postdrop" ];

    networking.hosts."127.0.0.1" = [ cfg.domain ];

    services.nginx.virtualHosts.${cfg.domain} = {
      kTLS = true;
      enableACME = true;
    };

    services.telegraf.extraConfig.inputs = {
      x509_cert = [
        { sources = [ "https://${cfg.domain}:443" ]; }
      ];
    };
  };
}
