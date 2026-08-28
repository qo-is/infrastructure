{
  inputs,
  ...
}:
let
  certs = import "${inputs.nixpkgs}/nixos/tests/common/acme/server/snakeoil-certs.nix";
  grafanaDomain = certs.domain;
  kanidmDomain = "id.${grafanaDomain}";
  oauth2Secret = "snakeoilOauth2Secret";
in
{
  args = {
    inherit grafanaDomain kanidmDomain;
  };

  nodes.server =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      inherit (lib) genAttrs mkForce;
      inherit (pkgs) writeText;
      oauth2SecretFile = writeText "kanidm-oauth2-grafana" oauth2Secret;
    in
    {
      qois.grafana = {
        enable = true;
        domain = grafanaDomain;
        sso = {
          domain = kanidmDomain;
          secretFile = mkForce oauth2SecretFile;
        };
      };

      qois.kanidm = {
        enable = true;
        domain = kanidmDomain;
        adminPasswordFile = writeText "kanidm-admin-password" "snakeoilAdminPassword";
        idmAdminPasswordFile = writeText "kanidm-idm-admin-password" "snakeoilIdmAdminPassword";
        oauth2Clients.grafana.secretFile = mkForce oauth2SecretFile;
      };

      # ACME issuance is covered by the kanidm module test; serve both vhosts and kanidm
      # itself from the snakeoil certificate instead.
      security.acme.certs = mkForce { };
      services.kanidm.server.settings = {
        tls_chain = mkForce certs.${grafanaDomain}.cert;
        tls_key = mkForce certs.${grafanaDomain}.key;
      };
      services.nginx.virtualHosts = genAttrs [ grafanaDomain kanidmDomain ] (_domain: {
        enableACME = mkForce false;
        sslCertificate = certs.${grafanaDomain}.cert;
        sslCertificateKey = certs.${grafanaDomain}.key;
      });

      security.pki.certificateFiles = [ certs.ca.cert ];

      qois.postgresql.package = pkgs.postgresql;

      # Dummy sops file so secret paths resolve at eval time; nothing reads them at
      # runtime, every consumer is pointed at a plain file above.
      sops.defaultSopsFile = builtins.toFile "dummy-secrets" (
        builtins.toJSON {
          grafana = {
            admin = {
              user = "unused";
              password = "unused";
            };
            secret_key = "unused";
          };
          kanidm = {
            admin-password = "unused";
            idm-admin-password = "unused";
            oauth2.grafana = "unused";
          };
        }
      );
      qois.sharedSecretsFile = mkForce config.sops.defaultSopsFile;

      services.grafana.settings.security = mkForce {
        admin_user = "testadmin";
        admin_password = "snakeoilpwd";
        secret_key = "snakeoil-test-secret-key";
        disable_gravatar = true;
      };
    };
}
