{ pkgs, ... }:
{ config, ... }:
let
  grafanaDomain = "monitoring.${config.kanidmFixture.caDomain}";
in
{
  imports = [ ../kanidm-relying-party/test-fixture.nix ];

  kanidmFixture = {
    oauth2Secrets.grafana = "snakeoilOauth2Secret";
    secrets.grafana = {
      admin = {
        user = "testadmin";
        password = "snakeoilpwd";
      };
      secret_key = "snakeoil-test-secret-key";
    };
    # Grafana exchanges the code with kanidm.
    pebbleCaClients = [ "grafana" ];
  };

  args = { inherit grafanaDomain; };

  nodes.server = {
    qois.kanidm-grafana.enable = true;

    qois.grafana = {
      enable = true;
      domain = grafanaDomain;
    };
    qois.postgresql.package = pkgs.postgresql;
  };
}
