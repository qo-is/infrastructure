{
  config,
  lib,
  ...
}:
# Binds grafana to kanidm as an OIDC relying party. Both sides may live on different
# hosts, so each half activates on its own and the shared client secret is declared here.
let
  inherit (lib)
    mkIf
    mkMerge
    mkOption
    optional
    ;
  inherit (lib.types)
    attrsOf
    bool
    listOf
    path
    str
    ;

  kanidm = config.qois.kanidm;
  grafana = config.qois.grafana;
  # The client is provisioned wherever kanidm runs, even if grafana runs on another host.
  provisionClient = kanidm.enable && grafana.sso.enable;
  configureGrafana = grafana.enable && grafana.sso.enable;

  clientId = grafana.sso.clientId;
  secretName = "kanidm/oauth2/${clientId}";
in
{
  options.qois.grafana.sso = {
    enable = mkOption {
      type = bool;
      default = true;
      description = ''
        Single sign-on through an OIDC provider. The local admin account stays available
        as a fallback.
      '';
    };

    domain = mkOption {
      type = str;
      default = "id.qo.is";
      description = "Domain of the OIDC provider.";
    };

    clientId = mkOption {
      type = str;
      default = "grafana";
      description = "OAuth2 client identifier registered with the provider.";
    };

    scopes = mkOption {
      type = listOf str;
      default = [
        "openid"
        "email"
        "profile"
      ];
      description = "Scopes requested from the provider.";
    };

    roles = mkOption {
      type = attrsOf (listOf str);
      default = {
        sysadmin = [ "GrafanaAdmin" ];
      };
      description = ''
        Maps a kanidm group name to the grafana role values its members receive through
        the `groups` claim.
      '';
    };

    secretFile = mkOption {
      type = path;
      description = "Path to a file holding the OAuth2 client secret, readable by grafana.";
    };
  };

  config = mkMerge [
    (mkIf provisionClient {
      qois.kanidm.oauth2Clients.${clientId} = {
        displayName = "Grafana";
        originUrl = "https://${grafana.domain}/login/generic_oauth";
        originLanding = "https://${grafana.domain}/";
        inherit (grafana.sso) roles scopes;
        secretFile = config.sops.secrets.${secretName}.path;
      };
    })

    (mkIf configureGrafana {
      qois.grafana.sso.secretFile = config.sops.secrets.${secretName}.path;
    })

    (mkIf (provisionClient || configureGrafana) {
      sops.secrets.${secretName} = {
        sopsFile = config.qois.sharedSecretsFile;
        mode = "0440";
        owner = if kanidm.enable then "kanidm" else config.users.users.grafana.name;
        group = if configureGrafana then config.users.users.grafana.group else "kanidm";
        restartUnits =
          optional provisionClient "kanidm.service" ++ optional configureGrafana "grafana.service";
      };
    })
  ];
}
