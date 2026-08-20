{ lib, ... }:
{
  # Default `virtualisation.vlans = [ 1 ]` gives each node an "eth1"
  # interface addressed 192.168.1.<nodeNumber>; nodes are numbered
  # alphabetically: backend=1, client=2, server=3.
  nodes.backend =
    { ... }:
    {
      # behindLoadbalancer gives us defaultListen/real_ip trust for the
      # production loadbalancer hosts (lindberg, cyprianspitz) from the qois
      # nginx module; here we additionally trust the test's own haproxy node
      # ("server", 192.168.1.3).
      qois.nginx.behindLoadbalancer = true;
      services.nginx = {
        enable = true;
        appendHttpConfig = "set_real_ip_from 192.168.1.3;\n";
        virtualHosts."test.example.com" = {
          locations."/".extraConfig = ''
            default_type text/plain;
            return 200 $remote_addr;
          '';
        };
      };
      networking.firewall.allowedTCPPorts = [ 80 ];
    };

  nodes.client = { ... }: { };

  nodes.server =
    { ... }:
    {
      qois.loadbalancer = {
        enable = true;
        domains = {
          "test.example.com" = "backend";
        };
        hostmap = {
          "backend" = "192.168.1.1";
        };
        extraConfig = "";
      };

      qois.telegraf.enable = true;
      services.telegraf.extraConfig.agent.interval = lib.mkForce "50ms";
    };
}
