{ lib, pkgs }:

let
  inherit (lib)
    concatMapStringsSep
    concatStringsSep
    optionalString
    range
    stringLength
    ;
  inherit (builtins) substring;

  txtChunkSize = 255;
  splitTxt =
    text:
    concatMapStringsSep " " (chunk: ''"${chunk}"'') (
      map (i: substring (i * txtChunkSize) txtChunkSize text) (
        range 0 ((stringLength text - 1) / txtChunkSize)
      )
    );

  renderData = record: if record.type == "TXT" then splitTxt record.data else record.data;

  renderRecord =
    record:
    concatStringsSep "\t" [
      record.name
      (optionalString (record.ttl != null) (toString record.ttl))
      "IN"
      record.type
      (renderData record)
    ];

  renderSoa =
    domain: soa:
    concatStringsSep " " [
      "${domain}."
      "IN"
      "SOA"
      soa.primaryNameserver
      soa.hostmaster
      "("
      "1" # Superseded by knot's serial-policy, see nixos-modules/knot/default.nix.
      (toString soa.refresh)
      (toString soa.retry)
      (toString soa.expire)
      (toString soa.minimum)
      ")"
    ];

  renderZone = domain: zone: ''
    $ORIGIN ${domain}.
    $TTL ${toString zone.ttl}

    ${renderSoa domain zone.soa}

    ${concatMapStringsSep "\n" renderRecord zone.records}
  '';
in
{
  mkZoneStorage =
    zones:
    pkgs.buildEnv {
      name = "knot-zones";
      paths = lib.mapAttrsToList (
        domain: zone: pkgs.writeTextDir "${domain}.zone" (renderZone domain zone)
      ) zones;
    };

  zoneFileName = domain: "${domain}.zone";
}
