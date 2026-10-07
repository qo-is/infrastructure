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
  idmAdminPassword = "snakeoilIdmAdminPassword";
  caFile = "/tmp/pebble-ca.crt";
  caBundle = "/run/pebble-ca-bundle.crt";
  mailRecipient = "bob@example.test";
  smtpsPort = 1465;
in
{
  args = {
    inherit
      caDomain
      caFile
      serverDomain
      oauth2Secret
      idmAdminPassword
      mailRecipient
      ;
  };

  nodes = {
    # Pebble, issuing the certificate kanidm serves. It resolves serverDomain to the
    # server node by scanning every node's security.acme.certs.
    # Mailpit is the SMTP relay the mail sender delivers to.
    acme =
      { pkgs, ... }:
      {
        imports = [ "${inputs.nixpkgs}/nixos/tests/common/acme/server" ];

        services.mailpit.instances.relay = {
          smtp = "[::]:${toString smtpsPort}";
          smtp-tls-cert = "${certs.${caDomain}.cert}";
          smtp-tls-key = "${certs.${caDomain}.key}";
          smtp-require-tls = true;
          smtp-auth-accept-any = true;
        };
        networking.firewall.allowedTCPPorts = [ smtpsPort ];
        environment.systemPackages = [ pkgs.curl ];
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
          package = pkgs.kanidmWithSecretProvisioning_1_11;
          domain = serverDomain;
          adminPasswordFile = writeText "kanidm-admin-password" "snakeoilAdminPassword";
          idmAdminPasswordFile = writeText "kanidm-idm-admin-password" idmAdminPassword;

          oauth2Clients.grafana = {
            displayName = "Grafana";
            originUrl = "https://${serverDomain}/login/generic_oauth";
            originLanding = "https://${serverDomain}/";
            roles.sysadmin = [ "GrafanaAdmin" ];
            secretFile = writeText "kanidm-oauth2-grafana" oauth2Secret;
          };

          mailSender = {
            enable = true;
            relay = "smtps://${caDomain}:${toString smtpsPort}";
            username = "kanidm";
            passwordFile = writeText "kanidm-mail-password" "snakeoilMailPassword";
            fromAddress = "kanidm@${caDomain}";
          };
        };

        services.kanidm.provision.persons.bob = {
          displayName = "Bob";
          mailAddresses = [ mailRecipient ];
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

        # The mail sender reaches kanidm through nginx and the relay through snakeoil
        # certificates, so it needs pebble's CA next to the system trust store.
        systemd.services.pebble-ca-bundle = {
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          path = [ pkgs.curl ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            until curl -sf https://${caDomain}:15000/roots/0 > ${caBundle}.tmp; do
              sleep 1
            done
            cat /etc/ssl/certs/ca-certificates.crt >> ${caBundle}.tmp
            mv ${caBundle}.tmp ${caBundle}
          '';
        };
        systemd.services.kanidm-mail-sender = {
          after = [ "pebble-ca-bundle.service" ];
          requires = [ "pebble-ca-bundle.service" ];
          environment.SSL_CERT_FILE = caBundle;
        };

        environment.systemPackages = [
          pkgs.curl
          pkgs.openldap
        ];
      };
  };
}
