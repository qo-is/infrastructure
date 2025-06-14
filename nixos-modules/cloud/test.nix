{
  ...
}:
{
  # Note: This extends the default configuration from ${self}/checks/nixos-modules
  nodes.webserver =
    { pkgs, lib, ... }:
    let
      inherit (pkgs) curl gnugrep;
      inherit (lib) mkForce genAttrs const;
    in
    {
      qois.cloud = {
        enable = true;
        domain = "cloud.example.com";
        package = pkgs.nextcloud31;
        adminpassFile = (pkgs.writeText "nextcloud-test-adminpass-file" "super secret password").outPath;
      };

      qois.postgresql.package = pkgs.postgresql;
      sops.secrets = mkForce { };

      # Disable TLS services
      services.nginx.virtualHosts = genAttrs [ "cloud.example.com" ] (const {
        forceSSL = mkForce false;
        enableACME = mkForce false;
      });

      # Test environment
      environment.systemPackages = [
        curl
        gnugrep
      ];
    };
}
