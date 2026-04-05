{ ... }:
{
  nodes.host =
    { ... }:
    {
      imports = [
        ./default.nix
        ../microvm/default.nix
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
          index = 2;
        };
      };

      networking.nat = {
        enable = true;
        externalInterface = "eth0";
      };
    };
}
