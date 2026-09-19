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
    mkIf
    ;

  cfg = config.qois.kanidm-grafana;
  kanidm = config.qois.kanidm;
  grafana = config.qois.grafana;

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
  config = mkIf (cfg.enable && grafana.enable) {
    sops.secrets."${cfg.secretKey}/grafana" =
      let
        user = config.users.users.grafana;
      in
      {
        key = cfg.secretKey;
        sopsFile = kanidm.secretsFile;
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
  };
}
