{
  inputs,
  ...
}:
let
  certs = import "${inputs.nixpkgs}/nixos/tests/common/acme/server/snakeoil-certs.nix";
  serverDomain = certs.domain;
  serverIp = "192.168.1.2";
  oauth2Secret = "snakeoilOauth2Secret";
in
{
  args = {
    inherit serverDomain oauth2Secret;
  };

  nodes = {
    # Separate node to verify that the LDAPS port is not reachable over the network.
    client =
      { pkgs, ... }:
      {
        networking.extraHosts = "${serverIp} ${serverDomain}";
        security.pki.certificateFiles = [ certs.ca.cert ];
        environment.systemPackages = [ pkgs.openldap ];
      };

    server =
      { pkgs, lib, ... }:
      let
        inherit (lib) mkForce;
        inherit (pkgs) writeText;
      in
      {
        security.pki.certificateFiles = [ certs.ca.cert ];

        qois.kanidm = {
          enable = true;
          domain = serverDomain;
          adminPasswordFile = writeText "kanidm-admin-password" "snakeoilAdminPassword";
          idmAdminPasswordFile = writeText "kanidm-idm-admin-password" "snakeoilIdmAdminPassword";

          oauth2Clients.grafana = {
            displayName = "Grafana";
            originUrl = "https://${serverDomain}/login/generic_oauth";
            originLanding = "https://${serverDomain}/";
            roles.admins = [ "Admin" ];
            secretGroup = "kanidm";
            secretFile = writeText "kanidm-oauth2-grafana" oauth2Secret;
          };
        };

        # TODO: Migrate this to the testing helper acme server
        services.kanidm.server.settings = {
          tls_chain = mkForce certs.${serverDomain}.cert;
          tls_key = mkForce certs.${serverDomain}.key;
        };
        security.acme.certs = mkForce { };
        services.nginx.virtualHosts.${serverDomain} = {
          enableACME = mkForce false;
          sslCertificate = certs.${serverDomain}.cert;
          sslCertificateKey = certs.${serverDomain}.key;
        };

        sops.secrets = mkForce { };

        networking.firewall.allowedTCPPorts = [
          80
          443
        ];

        qois.telegraf.enable = mkForce true;
        services.telegraf.extraConfig.agent.interval = mkForce "50ms";

        environment.systemPackages = [ pkgs.openldap ];
      };
  };
}
