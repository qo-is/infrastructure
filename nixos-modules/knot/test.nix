{
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkForce;

  primaryIp = "192.168.1.1";
  secondaryIp = "192.168.1.2";

  # DO NOT USE pkgs.writeText FOR REAL KEYS, this puts secrets in the nix store!
  tsigKeyFile = pkgs.writeText "knot-tsig.conf" ''
    key:
      - id: xfr
        algorithm: hmac-sha256
        secret: zOYgOgnzx3TGe5J5I/0kxd7gTcxXhLYMEq3Ek3fY37s=
  '';

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
      inherit tsigKeyFile;
      # Low enough that a handful of queries from the secondary trips the limiter.
      rateLimit.responsesPerSecond = 1;
      zones."qo.is".secondaries.test.address = secondaryIp;
    };

    # keyFiles disables the build time config check, but the key is a test dummy here
    # so the generated configuration can still be validated in CI.
    services.knot.checkConfig = mkForce true;

    qois.telegraf.enable = mkForce true;
    services.telegraf.extraConfig.agent.interval = mkForce "50ms";
    # Only the prometheus input (scraping the knot exporter) is needed for this test;
    # keep in sync with nixos-modules/knot/default.nix's
    # services.telegraf.extraConfig.inputs.prometheus.
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
      keyFiles = [ tsigKeyFile ];
      settings = {
        server.listen = [ "0.0.0.0@53" ];
        remote.primary = {
          address = "${primaryIp}@53";
          key = "xfr";
        };
        acl.notify_from_primary = {
          address = primaryIp;
          key = "xfr";
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
