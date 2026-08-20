{ ... }:
{
  nodes = {
    server =
      { ... }:
      {
        qois.loki.enable = true;

        # qois.loki only opens its port on the wg-backplane interface, which
        # doesn't exist in this test's virtual network.
        networking.firewall.allowedTCPPorts = [ 3100 ];
      };

    client =
      { lib, ... }:
      {
        qois.vector = {
          enable = lib.mkForce true;
          lokiEndpoint = "http://server:3100";
        };
      };
  };
}
