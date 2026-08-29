{
  lib,
  ...
}:
let
  inherit (lib) mkForce;

  primaryIp = "192.168.1.1";
  secondaryIp = "192.168.1.2";

  staticIp = address: {
    networking.useDHCP = false;
    networking.interfaces.eth1.ipv4.addresses = mkForce [
      {
        inherit address;
        prefixLength = 24;
      }
    ];
  };
in
{
  args = { inherit primaryIp secondaryIp; };

  nodes.primary = {
    imports = [ (staticIp primaryIp) ];

    qois.knot = {
      enable = true;
      listenAddresses = [ "0.0.0.0@53" ];
      # Low enough that a handful of queries from the secondary trips the limiter.
      rateLimit.responsesPerSecond = 1;
      zones."qo.is".secondaries.test.address = secondaryIp;
    };

    qois.telegraf.enable = mkForce true;
    services.telegraf.extraConfig.agent.interval = mkForce "50ms";
    services.telegraf.extraConfig.inputs = mkForce {
      prometheus = [
        {
          urls = [ "http://127.0.0.1:9433/metrics" ];
          metric_version = 2;
        }
      ];
    };

    sops.secrets = mkForce { };
  };

  nodes.secondary = {
    imports = [ (staticIp secondaryIp) ];

    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };

    services.knot = {
      enable = true;
      settings = {
        server.listen = [ "0.0.0.0@53" ];
        remote.primary.address = "${primaryIp}@53";
        acl.notify_from_primary = {
          address = primaryIp;
          action = "notify";
        };
        zone."qo.is" = {
          master = "primary";
          acl = "notify_from_primary";
          dnssec-signing = false;
        };
      };
    };

    sops.secrets = mkForce { };
  };
}
