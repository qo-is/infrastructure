{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    concatMapAttrs
    mapAttrs
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    optional
    optionalAttrs
    replaceStrings
    ;
  inherit (lib.types)
    attrsOf
    ints
    listOf
    nullOr
    path
    str
    submodule
    ;

  cfg = config.qois.knot;
  zoneFile = import ./zone-file.nix { inherit lib pkgs; };

  stateDir = "/var/lib/knot";
  tsigKeyId = "xfr";
  dnssecPolicyId = "qois";
  submissionId = "parent-check";
  resolverRemoteId = "validating-resolvers";
  sopsTsigSecret = "knot/xfr-secret";
  sopsTsigTemplate = "knot-tsig.conf";

  hasTsigKey = cfg.tsigKeyFile != null;

  remoteId = domain: name: "${replaceStrings [ "." ] [ "-" ] domain}-${name}";

  secondaryRemotes = concatMapAttrs (
    domain: zone:
    concatMapAttrs (name: secondary: {
      ${remoteId domain name} = {
        address = "${secondary.address}@${toString secondary.port}";
      }
      // optionalAttrs hasTsigKey { key = tsigKeyId; };
    }) zone.secondaries
  ) cfg.zones;

  recordType = {
    options = {
      name = mkOption {
        type = str;
        example = "www.qo.is.";
        description = "Owner name of the record. Fully qualified names must end with a dot.";
      };

      type = mkOption {
        type = str;
        example = "CNAME";
        description = "Record type.";
      };

      ttl = mkOption {
        type = nullOr ints.unsigned;
        default = null;
        description = "Record TTL. Falls back to the zone's default TTL when unset.";
      };

      data = mkOption {
        type = str;
        example = "0 mx.qo.is.";
        description = "Complete record data, including priorities and weights where applicable.";
      };
    };
  };

  soaType = {
    options = {
      primaryNameserver = mkOption {
        type = str;
        example = "ns1.qo.is.";
        description = "Primary nameserver of the zone.";
      };

      hostmaster = mkOption {
        type = str;
        example = "hostmaster.qo.is.";
        description = "Zone contact mailbox in SOA notation.";
      };

      refresh = mkOption {
        type = ints.unsigned;
        default = 600;
        description = "Interval in which secondaries check for zone updates.";
      };

      retry = mkOption {
        type = ints.unsigned;
        default = 3600;
        description = "Interval after which secondaries retry a failed refresh.";
      };

      expire = mkOption {
        type = ints.unsigned;
        default = 604800;
        description = "Time after which secondaries stop answering for an unrefreshed zone.";
      };

      minimum = mkOption {
        type = ints.unsigned;
        default = 600;
        description = "Negative caching TTL.";
      };
    };
  };

  secondaryType = {
    options = {
      address = mkOption {
        type = str;
        example = "80.74.136.136";
        description = "Address of the secondary, notified about zone changes and allowed to transfer it.";
      };

      port = mkOption {
        type = ints.positive;
        default = 53;
        description = "Port on which the secondary receives notifications.";
      };
    };
  };

  zoneType = {
    options = {
      dnssec = mkEnableOption "DNSSEC signing of this zone";

      ttl = mkOption {
        type = ints.unsigned;
        default = 86400;
        description = "Default TTL for records that do not set one themselves.";
      };

      soa = mkOption { type = submodule soaType; };

      records = mkOption {
        type = listOf (submodule recordType);
        default = [ ];
        description = "Records of this zone. The SOA record is generated from `soa`.";
      };

      secondaries = mkOption {
        type = attrsOf (submodule secondaryType);
        default = { };
        description = "Secondary nameservers that slave this zone.";
      };
    };
  };
in
{
  imports = [ ./qo-is-zone.nix ];

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

    tsigKeyFile =
      mkOption {
        type = nullOr path;
        description = ''
          File holding a knot `key:` section with the id `${tsigKeyId}`, used to authenticate zone
          transfers to the secondaries. Without it, secondaries are authorised by address only.
        '';
      }
      // (
        if config.sops.secrets ? ${sopsTsigSecret} then
          { default = config.sops.templates.${sopsTsigTemplate}.path; }
        else
          { default = null; }
      );

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

    zones = mkOption {
      type = attrsOf (submodule zoneType);
      default = { };
      description = "Zones served authoritatively, keyed by domain.";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = {
      allowedTCPPorts = [ 53 ];
      allowedUDPPorts = [ 53 ];
    };

    # Holds the DNSSEC private keys and the zone journal.
    qois.backup-client.includePaths = [ stateDir ];

    sops.templates = optionalAttrs (config.sops.secrets ? ${sopsTsigSecret}) {
      ${sopsTsigTemplate} = {
        content = ''
          key:
            - id: ${tsigKeyId}
              algorithm: hmac-sha256
              secret: ${config.sops.placeholder.${sopsTsigSecret}}
        '';
        owner = "knot";
        restartUnits = [ "knot.service" ];
      };
    };

    services.knot = {
      enable = true;
      keyFiles = optional hasTsigKey cfg.tsigKeyFile;

      settings = {
        server = {
          listen = cfg.listenAddresses;
          automatic-acl = true;
        };

        log.syslog.any = "info";

        database.storage = stateDir;

        remote = secondaryRemotes // {
          ${resolverRemoteId}.address = [
            "9.9.9.9@53"
            "1.1.1.1@53"
          ];
        };

        submission.${submissionId} = {
          parent = [ resolverRemoteId ];
          check-interval = "1h";
        };

        policy.${dnssecPolicyId} = {
          algorithm = "ecdsap256sha256";
          # Rolled manually, gated on the DS record appearing at the registrar.
          ksk-lifetime = 0;
          zsk-lifetime = "30d";
          nsec3 = true;
          nsec3-iterations = 0;
          cds-cdnskey-publish = "rollover";
          ksk-submission = submissionId;
        };

        mod-rrl.default = {
          rate-limit = cfg.rateLimit.responsesPerSecond;
          inherit (cfg.rateLimit) slip whitelist;
        };

        mod-stats.default = {
          query-type = true;
          response-code = true;
          request-protocol = true;
        };

        template.default = {
          storage = zoneFile.mkZoneStorage cfg.zones;
          # Zone files come from the immutable nix store, so knot keeps all changes
          # (including DNSSEC signatures) in its journal and owns the serial itself.
          zonefile-sync = -1;
          zonefile-load = "difference-no-serial";
          journal-content = "all";
          serial-policy = "dateserial";
          global-module = [
            "mod-rrl/default"
            "mod-stats/default"
          ];
        };

        zone = mapAttrs (
          domain: zone:
          {
            file = zoneFile.zoneFileName domain;
            dnssec-signing = zone.dnssec;
            notify = mapAttrsToList (name: _secondary: remoteId domain name) zone.secondaries;
          }
          // optionalAttrs zone.dnssec { dnssec-policy = dnssecPolicyId; }
        ) cfg.zones;
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
