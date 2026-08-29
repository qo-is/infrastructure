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
    optionalAttrs
    replaceStrings
    ;
  inherit (lib.types)
    attrsOf
    ints
    listOf
    nullOr
    str
    submodule
    ;

  cfg = config.qois.knot;
  zoneFile = import ./zone-file.nix { inherit lib pkgs; };

  dnssecPolicyId = "qois";
  submissionId = "parent-check";
  resolverRemoteId = "validating-resolvers";

  remoteId = domain: name: "${replaceStrings [ "." ] [ "-" ] domain}-${name}";

  secondaryRemotes = concatMapAttrs (
    domain: zone:
    concatMapAttrs (name: secondary: {
      ${remoteId domain name}.address = "${secondary.address}@${toString secondary.port}";
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
        description = ''
          Secondary nameservers that slave this zone. They are notified about zone changes and
          authorised to transfer the zone by their source address.
        '';
      };
    };
  };
in
{
  options.qois.knot.zones = mkOption {
    type = attrsOf (submodule zoneType);
    default = { };
    description = "Zones served authoritatively, keyed by domain.";
  };

  config = mkIf cfg.enable {
    services.knot.settings = {
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

      template.default = {
        storage = zoneFile.mkZoneStorage cfg.zones;
        # Zone files come from the immutable nix store, so knot keeps all changes
        # (including DNSSEC signatures) in its journal and owns the serial itself.
        zonefile-sync = -1;
        zonefile-load = "difference-no-serial";
        journal-content = "all";
        serial-policy = "dateserial";
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
}
