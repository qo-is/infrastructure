{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    attrNames
    flip
    genAttrs
    mkIf
    mkOption
    pipe
    types
    ;
  inherit (lib.types) listOf str;

  cfg = config.qois.backplane-net.hosts;
  defaultDomains = attrNames config.qois.loadbalancer.domains;
  defaultLoadbalancers = [ "lindberg" ];
in
{

  options.qois.backplane-net.hosts = {
    enable = mkOption {
      default = true;
      description = "Whether to enable hosts aliases for loadbalanced services. This prevents turnarounds over external networks for these services.";
      type = types.bool;
    };

    domains = mkOption {
      description = "Domains that are hosted by the backplane loadbalancer";
      type = listOf str;
      default = defaultDomains;
    };
    loadbalancers = mkOption {
      description = "List of Loadbalancer hostnames as listed in the backplane network";
      type = listOf str;
      default = defaultLoadbalancers;
    };
  };

  config = mkIf cfg.enable {

    networking.hosts = pipe cfg.loadbalancers [
      (map (hostname: config.qois.meta.network.virtual.backplane.hosts.${hostname}.v4.ip))
      (flip genAttrs (_lb: cfg.domains))
    ];

  };
}
