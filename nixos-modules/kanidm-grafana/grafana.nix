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
  party = config.qois.kanidm-relying-party.grafana;
  kanidm = config.qois.kanidm;
  grafana = config.qois.grafana;

  # Most privileged role first; a person gets the first one their claim carries.
  rolePrecedence = [
    "GrafanaAdmin"
    "Admin"
    "Editor"
  ];
  roleValues = concatLists (attrValues party.roles);
  # JMESPath picking the most privileged role a person is entitled to.
  roleAttributePath =
    concatMapStrings (role: "contains(groups[*], '${role}') && '${role}' || ") (
      filter (role: elem role roleValues) rolePrecedence
    )
    + "'Viewer'";
in
{
  config = mkIf (cfg.enable && grafana.enable) {
    services.grafana.settings."auth.generic_oauth" =
      let
        origin = "https://${kanidm.domain}";
      in
      {
        enabled = true;
        name = kanidm.domain;
        client_id = party.clientId;
        client_secret = "$__file{${party.secretFiles.consumer}}";
        scopes = concatStringsSep " " party.scopes;

        auth_url = "${origin}/ui/oauth2";
        token_url = "${origin}/oauth2/token";
        api_url = "${origin}/oauth2/openid/${party.clientId}/userinfo";
        use_pkce = true;

        login_attribute_path = "preferred_username";
        role_attribute_path = roleAttributePath;
        # The local admin account stays available as a fallback.
        role_attribute_strict = false;
        allow_assign_grafana_admin = true;
      };
  };
}
