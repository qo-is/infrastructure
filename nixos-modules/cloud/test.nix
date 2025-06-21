{
  ...
}:
{
  # Note: This extends the default configuration from ${self}/checks/nixos-modules
  nodes.webserver =
    { pkgs, lib, ... }:
    let
      inherit (pkgs) curl gnugrep;
      inherit (lib) mkForce;
      cloud-domain = "cloud.example.com";
    in
    {
      qois.cloud = {
        enable = true;
        domain = cloud-domain;
        package = pkgs.nextcloud31;
        adminpassFile = "${pkgs.writeText "adminpass" "insecure"}"; # Don't try this at home!
      };

      qois.postgresql.package = pkgs.postgresql;
      sops.secrets = mkForce { };

      # Disable TLS services
      services.nginx.virtualHosts."${cloud-domain}" = {
        forceSSL = mkForce false;
        enableACME = mkForce false;
      };

      # Test environment
      environment.systemPackages = [
        curl
        gnugrep
      ];
    };
}
