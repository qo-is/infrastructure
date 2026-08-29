{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    ;
  inherit (lib.types)
    ints
    listOf
    str
    ;

  cfg = config.qois.knot;

  stateDir = "/var/lib/knot";
in
{
  imports = [
    ./zones.nix
    ./qo-is-zone.nix
  ];

  options.qois.knot = {
    enable = mkEnableOption "authoritative DNS server";

    listenAddresses = mkOption {
      type = listOf str;
      default = [ "0.0.0.0@53" ];
      example = [ "10.1.1.250@53" ];
      description = ''
        Addresses knot answers queries on. Hosts that already run another resolver on port 53
        must list their addresses explicitly instead of using the wildcard.
      '';
    };

    rateLimit = {
      responsesPerSecond = mkOption {
        type = ints.positive;
        default = 200;
        description = "Responses per second granted to a single client subnet.";
      };

      slip = mkOption {
        type = ints.positive;
        default = 2;
        description = "Every n-th rate limited response is answered truncated instead of dropped.";
      };

      whitelist = mkOption {
        type = listOf str;
        default = [
          "127.0.0.0/8"
        ]
        ++ mapAttrsToList (
          _name: net: "${net.v4.id}/${toString net.v4.prefixLength}"
        ) config.qois.meta.network.virtual;
        description = "Networks exempt from rate limiting.";
      };
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };

    # Holds the DNSSEC private keys and the zone journal.
    qois.backup-client.includePaths = [ stateDir ];

    services.knot = {
      enable = true;

      settings = {
        server = {
          listen = cfg.listenAddresses;
          automatic-acl = true;
        };

        log.syslog.any = "info";

        database.storage = stateDir;

        mod-rrl.default = {
          rate-limit = cfg.rateLimit.responsesPerSecond;
          inherit (cfg.rateLimit) slip whitelist;
        };

        mod-stats.default = {
          query-type = true;
          response-code = true;
          request-protocol = true;
        };

        template.default.global-module = [
          "mod-rrl/default"
          "mod-stats/default"
        ];
      };
    };

    services.prometheus.exporters.knot = {
      enable = true;
      listenAddress = "127.0.0.1";
    };

    services.telegraf.extraConfig.inputs.prometheus = [
      {
        urls = [
          "http://127.0.0.1:${toString config.services.prometheus.exporters.knot.port}/metrics"
        ];
        metric_version = 2;
      }
    ];
  };
}
