{ inputs, ... }:
let
  certs = import "${inputs.nixpkgs}/nixos/tests/common/acme/server/snakeoil-certs.nix";
  serverDomain = certs.domain;
in
{
  args = {
    inherit serverDomain;
  };
  # Note: This extends the default configuration from ${self}/checks/nixos-modules
  nodes = {
    # Using a separated client and server node to verify that the firewall rules work as expected
    client =
      { pkgs, ... }:
      {
        # Resolve serverDomain to the server node and trust the snakeoil CA
        networking.extraHosts = "192.168.1.2 ${serverDomain}";
        security.pki.certificateFiles = [ certs.ca.cert ];

        environment.systemPackages = [
          pkgs.curl
          pkgs.jq
        ];
      };
    server =
      {
        pkgs,
        lib,
        ...
      }:
      {
        qois.grafana = {
          enable = true;
          domain = serverDomain;
        };

        # Use snakeoil certs instead of ACME
        services.nginx.virtualHosts."${serverDomain}" = {
          enableACME = lib.mkForce false;
          sslCertificate = certs.${serverDomain}.cert;
          sslCertificateKey = certs.${serverDomain}.key;
        };
        networking.firewall.allowedTCPPorts = [
          80
          443
        ];

        qois.postgresql.package = pkgs.postgresql;

        services.grafana.settings = {
          security = {
            admin_user = "testadmin";
            # env-var provider avoids the plaintext-in-Nix-store eval warning
            admin_password = "$__env{GF_SECURITY_ADMIN_PASSWORD}";
            disable_initial_admin_creation = lib.mkForce false;
          };
        };
        systemd.services.grafana.environment.GF_SECURITY_ADMIN_PASSWORD = "snakeoilpwd";
      };
  };
}
