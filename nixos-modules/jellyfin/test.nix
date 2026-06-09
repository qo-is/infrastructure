{
  inputs,
  pkgs,
  ...
}:
let
  jellyfinDomain = "jellyfin.acme.test";
  certs = import "${inputs.nixpkgs}/nixos/tests/common/acme/server/generate-certs.nix" {
    inherit pkgs;
    domain = jellyfinDomain;
  };
in
{
  args = { inherit jellyfinDomain; };

  nodes.server =
    { lib, ... }:
    {
      # Jellyfin asserts >=2 GiB free at /var/lib/jellyfin/data; default VM disk is ~888 MiB
      virtualisation.diskSize = 4096;

      qois.jellyfin.enable = true;
      qois.jellyfin.domain = "acme.test";

      nixflix.nginx.addHostsEntries = true;

      # Clear all SOPS secrets — test VM has no decryption keys
      sops.secrets = lib.mkForce { };

      # Override production secrets with plain strings (no credential files in test environment)
      nixflix.jellyfin.apiKey = lib.mkForce "abcdef1234567890abcdef1234567890";
      systemd.services.jellyfin-api-key.serviceConfig.LoadCredential = lib.mkForce [ ];
      nixflix.jellyfin.users.admin.password = lib.mkForce "test-admin-password";
      systemd.services.jellyfin-credential-setup.script = lib.mkForce "true";
      systemd.services.jellyfin-credential-setup.serviceConfig.LoadCredential = lib.mkForce [ ];

      security.pki.certificateFiles = [ "${certs}/ca.cert.pem" ];
      services.nginx.virtualHosts.${jellyfinDomain} = {
        enableACME = lib.mkForce false;
        sslCertificate = "${certs}/${jellyfinDomain}.cert.pem";
        sslCertificateKey = "${certs}/${jellyfinDomain}.key.pem";
      };
    };
}
