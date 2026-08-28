{
  inputs,
  ...
}:
let
  certs = import "${inputs.nixpkgs}/nixos/tests/common/acme/server/snakeoil-certs.nix";
  caDomain = certs.domain;
  serverDomain = "id.${caDomain}";
  serverIp = "192.168.1.3";
  oauth2Secret = "snakeoilOauth2Secret";
in
{
  args = {
    inherit caDomain serverDomain oauth2Secret;
  };

  nodes = {
    # Pebble, issuing the certificate kanidm serves. It resolves serverDomain to the
    # server node by scanning every node's security.acme.certs.
    acme =
      { ... }:
      {
        imports = [ "${inputs.nixpkgs}/nixos/tests/common/acme/server" ];
      };

    # Separate node to verify that the LDAPS port is not reachable over the network.
    client =
      { pkgs, ... }:
      {
        networking.extraHosts = "${serverIp} ${serverDomain}";
        security.pki.certificateFiles = [ certs.ca.cert ];
        environment.systemPackages = [
          pkgs.curl
          pkgs.openldap
        ];
      };

    server =
      { pkgs, lib, ... }:
      let
        inherit (lib) mkForce;
        inherit (pkgs) writeText;
      in
      {
        security.pki.certificateFiles = [ certs.ca.cert ];
        security.acme.defaults.server = "https://${caDomain}/dir";

        qois.kanidm = {
          enable = true;
          domain = serverDomain;
          adminPasswordFile = writeText "kanidm-admin-password" "snakeoilAdminPassword";
          idmAdminPasswordFile = writeText "kanidm-idm-admin-password" "snakeoilIdmAdminPassword";

          oauth2Clients.grafana = {
            displayName = "Grafana";
            originUrl = "https://${serverDomain}/login/generic_oauth";
            originLanding = "https://${serverDomain}/";
            roles.sysadmin = [ "GrafanaAdmin" ];
            secretFile = writeText "kanidm-oauth2-grafana" oauth2Secret;
          };
        };

        sops.secrets = mkForce { };
        # Covered by the kanidm-grafana module test, and it would need a sops secret here.
        qois.grafana.sso.enable = false;

        networking.firewall.allowedTCPPorts = [
          80
          443
        ];

        qois.telegraf.enable = mkForce true;
        services.telegraf.extraConfig.agent.interval = mkForce "50ms";

        environment.systemPackages = [
          pkgs.curl
          pkgs.openldap
        ];
      };
  };
}
