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
      # Setup simple localhost page with an example.com redirect
      qois.static-page = {
        enable = true;
        pages."localhost".domainAliases = [ "example.com" ];
      };

      # Disable TLS services
      services.nginx.virtualHosts = genAttrs [ "localhost" "example.com" ] (const {
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
