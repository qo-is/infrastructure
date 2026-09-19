{
  inputs,
  ...
}:
let
  certs = import "${inputs.nixpkgs}/nixos/tests/common/acme/server/snakeoil-certs.nix";
  caDomain = certs.domain;
  grafanaDomain = "monitoring.${caDomain}";
  kanidmDomain = "id.${caDomain}";
  oauth2Secret = "snakeoilOauth2Secret";
in
{
  args = {
    inherit caDomain grafanaDomain kanidmDomain;
  };

  nodes = {
    # Pebble, issuing both certificates. It resolves the domains to the server node by
    # scanning every node's security.acme.certs.
    acme =
      { ... }:
      {
        imports = [ "${inputs.nixpkgs}/nixos/tests/common/acme/server" ];
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

        qois.kanidm-grafana = {
          enable = true;
          secretFiles =
            let
              secretFile = writeText "kanidm-oauth2-grafana" oauth2Secret;
            in
            {
              kanidm = secretFile;
              grafana = secretFile;
            };
        };

        qois.grafana = {
          enable = true;
          domain = grafanaDomain;
        };

        qois.kanidm = {
          enable = true;
          package = pkgs.kanidmWithSecretProvisioning_1_11;
          domain = kanidmDomain;
          adminPasswordFile = writeText "kanidm-admin-password" "snakeoilAdminPassword";
          idmAdminPasswordFile = writeText "kanidm-idm-admin-password" "snakeoilIdmAdminPassword";
          secretsFile = mkForce config.sops.defaultSopsFile;
        };

        networking.firewall.allowedTCPPorts = [
          80
          443
        ];

        qois.postgresql.package = pkgs.postgresql;

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

        services.grafana.settings.security = mkForce {
          admin_user = "testadmin";
          admin_password = "snakeoilpwd";
          secret_key = "snakeoil-test-secret-key";
          disable_gravatar = true;
        };

        environment.systemPackages = [ pkgs.curl ];
      };
  };
}
