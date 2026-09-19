{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkIf;

  cfg = config.qois.kanidm-grafana;
  kanidm = config.qois.kanidm;
  grafana = config.qois.grafana;
in
{
  config = mkIf (cfg.enable && kanidm.enable) {
    sops.secrets."${cfg.secretKey}/kanidm" = {
      key = cfg.secretKey;
      sopsFile = kanidm.secretsFile;
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
  };
}
