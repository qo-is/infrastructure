{
  config,
  lib,
  ...
}:
# Binds grafana to kanidm as an OIDC relying party. Both sides may live on different
# hosts, so each half activates on its own and the shared client secret is declared here.
let
  inherit (lib)
    attrValues
    concatLists
    concatMapStrings
    concatStringsSep
    elem
    filter
    mkEnableOption
    mkIf
    mkMerge
    mkOption
    optional
    ;
  inherit (lib.types)
    attrsOf
    listOf
    path
    str
    ;

  cfg = config.qois.kanidm-grafana;
  kanidm = config.qois.kanidm;
  grafana = config.qois.grafana;

  secretName = "kanidm/oauth2/${cfg.clientId}";

  # Most privileged role first; a person gets the first one their claim carries.
  rolePrecedence = [
    "GrafanaAdmin"
    "Admin"
    "Editor"
  ];
  roleValues = concatLists (attrValues cfg.roles);
  # JMESPath picking the most privileged role a person is entitled to.
  roleAttributePath =
    concatMapStrings (role: "contains(groups[*], '${role}') && '${role}' || ") (
      filter (role: elem role roleValues) rolePrecedence
    )
    + "'Viewer'";
in
{
  options.qois.kanidm-grafana = {
    enable = mkEnableOption "grafana single sign-on through kanidm";

    clientId = mkOption {
      type = str;
      default = "grafana";
      description = "OAuth2 client identifier registered with kanidm.";
    };

    scopes = mkOption {
      type = listOf str;
      default = [
        "openid"
        "email"
        "profile"
      ];
      description = "Scopes grafana requests from kanidm.";
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
      default = config.sops.secrets.${secretName}.path;
      defaultText = ''config.sops.secrets."kanidm/oauth2/<clientId>".path'';
      description = "Path to a file holding the OAuth2 client secret.";
    };
  };

  config = mkIf cfg.enable (mkMerge [
    # The client is provisioned wherever kanidm runs, even if grafana runs on another host.
    (mkIf kanidm.enable {
      qois.kanidm.oauth2Clients.${cfg.clientId} = {
        displayName = "Grafana";
        originUrl = "https://${grafana.domain}/login/generic_oauth";
        originLanding = "https://${grafana.domain}/";
        inherit (cfg) roles scopes secretFile;
      };
    })

    (mkIf grafana.enable {
      services.grafana.settings."auth.generic_oauth" =
        let
          origin = "https://${kanidm.domain}";
        in
        {
          enabled = true;
          name = kanidm.domain;
          client_id = cfg.clientId;
          client_secret = "$__file{${cfg.secretFile}}";
          scopes = concatStringsSep " " cfg.scopes;

          auth_url = "${origin}/ui/oauth2";
          token_url = "${origin}/oauth2/token";
          api_url = "${origin}/oauth2/openid/${cfg.clientId}/userinfo";
          use_pkce = true;

          login_attribute_path = "preferred_username";
          role_attribute_path = roleAttributePath;
          # The local admin account stays available as a fallback.
          role_attribute_strict = false;
          allow_assign_grafana_admin = true;
        };
    })

    {
      sops.secrets.${secretName} = {
        sopsFile = kanidm.secretsFile;
        mode = "0440";
        owner = if kanidm.enable then "kanidm" else config.users.users.grafana.name;
        group = if grafana.enable then config.users.users.grafana.group else "kanidm";
        restartUnits = optional kanidm.enable "kanidm.service" ++ optional grafana.enable "grafana.service";
      };
    }
  ]);
}
