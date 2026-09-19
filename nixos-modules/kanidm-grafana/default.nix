{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkOption
    ;
  inherit (lib.types)
    attrsOf
    listOf
    path
    str
    ;

  cfg = config.qois.kanidm-grafana;
in
{
  imports = [
    ./kanidm.nix
    ./grafana.nix
  ];

  options.qois.kanidm-grafana = {
    enable = mkEnableOption "grafana single sign-on through kanidm";

    clientId = mkOption {
      type = str;
      default = "grafana";
      description = "OAuth2 client identifier registered with kanidm.";
    };

    secretKey = mkOption {
      type = str;
      internal = true;
      readOnly = true;
      default = "kanidm/oauth2/${cfg.clientId}";
      description = "Key of the OAuth2 client secret in the shared sops file.";
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
        kanidm = config.sops.secrets."${cfg.secretKey}/kanidm".path;
        grafana = config.sops.secrets."${cfg.secretKey}/grafana".path;
      };
      defaultText = ''paths of the "kanidm/oauth2/<clientId>" sops secrets'';
      description = ''
        Path to the OAuth2 client secret per consumer. Both entries decrypt the same key,
        so an override has to set both.
      '';
    };
  };
}
