{
  inputs,
  ...
}:
let
  certs = import "${inputs.nixpkgs}/nixos/tests/common/acme/server/snakeoil-certs.nix";
  serverDomain = certs.domain;
in
{
  args = { inherit serverDomain; };

  nodes.server =
    { pkgs, lib, ... }:
    let
      inherit (lib) mkForce;
      inherit (pkgs) writeText postgresql;
    in
    {
      security.pki.certificateFiles = [ certs.ca.cert ];
      qois.vault = {
        enable = true;
        domain = serverDomain;
      };

      qois.postgresql.package = postgresql;

      services.nginx.virtualHosts.${serverDomain} = {
        enableACME = mkForce false;
        sslCertificate = certs.${serverDomain}.cert;
        sslCertificateKey = certs.${serverDomain}.key;
      };

      services.vaultwarden.environmentFile = writeText "vaultwarden-test-env" "";
      sops.secrets = mkForce { };
    };
}
