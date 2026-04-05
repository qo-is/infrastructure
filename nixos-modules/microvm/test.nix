{ ... }:
{
  nodes.host =
    { pkgs, ... }:
    {
      imports = [
        ./default.nix
        ../microvm-secrets/default.nix
      ];

      qois.meta.network.microvm.test-net = {
        v4 = {
          id = "192.168.100.0";
          prefixLength = 24;
        };
        domain = "test-microvms.local";
      };

      qois.microvm-secrets = {
        enable = true;
        secrets.test-secret = {
          services = [ "test-vm" ];
        };
      };

      qois.microvm = {
        enable = true;
        netName = "test-net";

        services.test-vm = {
          enable = true;
          index = 2; # → 192.168.100.2
          openHostFirewallTCP = [ 8080 ];
          guestModules = [
            (
              { pkgs, ... }:
              {
                networking.firewall.allowedTCPPorts = [ 8080 ];
                systemd.services.simple-http = {
                  wantedBy = [ "multi-user.target" ];
                  after = [ "network-online.target" ];
                  wants = [ "network-online.target" ];
                  serviceConfig.ExecStart = "${pkgs.python3}/bin/python3 -m http.server 8080";
                };
              }
            )
          ];
        };
      };

      networking.nat = {
        enable = true;
        externalInterface = "eth0";
      };

      environment.systemPackages = [ pkgs.curl ];
    };
}
