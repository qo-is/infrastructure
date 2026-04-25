{
  inputs,
  lib,
  ...
}:
let
  certs = import "${inputs.nixpkgs}/nixos/tests/common/acme/server/snakeoil-certs.nix";
  serverDomain = certs.domain;
in
{
  args = { inherit serverDomain; };

  nodes.server =
    { pkgs, ... }:
    {
      security.pki.certificateFiles = [ certs.ca.cert ];
      qois.git = {
        enable = true;
        domain = serverDomain;
        msmtpPasswordFile = pkgs.writeText "msmtp-test-password" "dummy";
      };

      sops.secrets = lib.mkForce { };

      qois.postgresql.package = pkgs.postgresql;
      qois.telegraf.enable = true;
      services.telegraf.extraConfig.agent.interval = lib.mkForce "50ms";

      services.nginx.virtualHosts.${serverDomain} = {
        # TODO: Migrate this to testing helper acme server
        enableACME = lib.mkForce false;
        sslCertificate = certs.${serverDomain}.cert;
        sslCertificateKey = certs.${serverDomain}.key;
      };
    };
}
