{ ... }:
{ config, ... }:
let
  prometheusDomain = "prometheus.${config.kanidmFixture.caDomain}";
in
{
  imports = [ ../kanidm-relying-party/test-fixture.nix ];

  kanidmFixture = {
    oauth2Secrets.prometheus = "snakeoilOauth2Secret";
    secrets.oauth2-proxy.cookie-secret = "snakeoilCookieSecret0123456789ab";
    # oauth2-proxy fetches kanidm's discovery document.
    pebbleCaClients = [ "oauth2-proxy" ];
  };

  args = { inherit prometheusDomain; };

  nodes.server = {
    qois.prometheus = {
      enable = true;
      domain = prometheusDomain;
    };
    qois.alertmanager.enable = true;
    qois.kanidm-prometheus.enable = true;
  };
}
