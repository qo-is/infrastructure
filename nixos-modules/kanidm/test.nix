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
  caFile = "/tmp/pebble-ca.crt";
in
{
  args = {
    inherit
      caDomain
      caFile
      serverDomain
      oauth2Secret
      ;
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
      {
        config,
        pkgs,
        lib,
        ...
      }:
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

        networking.firewall.allowedTCPPorts = [
          80
          443
        ];

        qois.telegraf.enable = mkForce true;
        services.telegraf.extraConfig.agent.interval = mkForce "50ms";
        # Drop the host-level inputs of the telegraf module and srvos; only the inputs the
        # modules under test contribute are relevant here.
        services.telegraf.extraConfig.inputs = mkForce config.qois.telegraf.serviceInputs;
        # Pebble generates its issuing CA at startup, so the system trust store cannot
        # contain it. test.py downloads it here before restarting telegraf.
        systemd.services.telegraf.environment.SSL_CERT_FILE = caFile;

        environment.systemPackages = [
          pkgs.curl
          pkgs.openldap
        ];
      };
  };
}
