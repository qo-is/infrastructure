{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.qois.kanidm-grafana;
  grafana = config.qois.grafana;
in
{
  imports = [ ./grafana.nix ];

  options.qois.kanidm-grafana.enable = mkEnableOption "grafana single sign-on through kanidm";

  config = mkIf cfg.enable {
    qois.kanidm-relying-party.grafana = {
      enable = true;
      displayName = "Grafana";
      originUrl = "https://${grafana.domain}/login/generic_oauth";
      originLanding = "https://${grafana.domain}/";
      roles.sysadmin = [ "GrafanaAdmin" ];
      consumer =
        let
          user = config.users.users.grafana;
        in
        {
          inherit (grafana) enable;
          unit = "grafana";
          user = user.name;
          inherit (user) group;
        };
    };
  };
}
