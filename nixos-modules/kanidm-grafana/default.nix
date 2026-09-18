{
  config,
  lib,
  ...
}:
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

  secretKey = "kanidm/oauth2/${cfg.clientId}";
  clientSecret = {
    key = secretKey;
    sopsFile = kanidm.secretsFile;
  };

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

    secretFiles = mkOption {
      type = attrsOf path;
      default = {
        kanidm = config.sops.secrets."${secretKey}/kanidm".path;
        grafana = config.sops.secrets."${secretKey}/grafana".path;
      };
      defaultText = ''paths of the "kanidm/oauth2/<clientId>" sops secrets'';
      description = ''
        Path to the OAuth2 client secret per consumer. Both entries decrypt the same key,
        so an override has to set both.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    (mkIf kanidm.enable {
      sops.secrets."${secretKey}/kanidm" = clientSecret // {
        owner = config.systemd.services.kanidm.serviceConfig.User;
        restartUnits = [ "kanidm.service" ];
      };

      qois.kanidm.oauth2Clients.${cfg.clientId} = {
        displayName = "Grafana";
        originUrl = "https://${grafana.domain}/login/generic_oauth";
        originLanding = "https://${grafana.domain}/";
        inherit (cfg) roles scopes;
        secretFile = cfg.secretFiles.kanidm;
      };
    })

    (mkIf grafana.enable {
      sops.secrets."${secretKey}/grafana" =
        let
          user = config.users.users.grafana;
        in
        clientSecret
        // {
          owner = user.name;
          inherit (user) group;
          restartUnits = [ "grafana.service" ];
        };

      services.grafana.settings."auth.generic_oauth" =
        let
          origin = "https://${kanidm.domain}";
        in
        {
          enabled = true;
          name = kanidm.domain;
          client_id = cfg.clientId;
          client_secret = "$__file{${cfg.secretFiles.grafana}}";
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
  ]);
}
