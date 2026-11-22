# knot

## Overview

Authoritative DNS server (Knot DNS) with DNSSEC signing, rate limiting and zone rendering from Nix attrsets. Operational notes (key management, KSK rollover) live in the legacy [README](./README.md). Tested by `test.nix` / `test.py`.

## Interface

- `qois.knot.enable` (bool, default false) [default.nix:options.qois.knot.enable]
- `qois.knot.listenAddresses` (listOf str, default `[ "0.0.0.0@53" ]`) [default.nix:options.qois.knot.listenAddresses]
- `qois.knot.rateLimit.responsesPerSecond` (ints.positive, default 200) [default.nix:rateLimit.responsesPerSecond]
- `qois.knot.rateLimit.slip` (ints.positive, default 2) [default.nix:rateLimit.slip]
- `qois.knot.rateLimit.whitelist` (listOf str, default `127.0.0.0/8` plus every `qois.meta.network.virtual` v4 network) [default.nix:rateLimit.whitelist]
- `qois.knot.zones` (attrsOf submodule, default `{ }`, keyed by domain) [zones.nix:options.qois.knot.zones]
  - `dnssec` (enable option), `ttl` (ints.unsigned, default 86400), `soa` (primaryNameserver, hostmaster, refresh 600, retry 3600, expire 604800, minimum 600), `records` (listOf submodule name/type/ttl/data, default `[ ]`), `secondaries` (attrsOf submodule address/port, port default 53) [zones.nix:zoneType]
- Zone file rendering helpers `mkZoneStorage`, `zoneFileName` [zone-file.nix:mkZoneStorage]
- Zone `qo.is` with dnssec, SOA `ns1.qo.is.`, secondaries `ch-inter-ch`/`ch-inter-de`/`ch-inter-nl`, records derived from `qois.meta.network.*` hosts, `qois.loadbalancer.domains` CNAMEs to lindberg, mail/SPF/DKIM/SRV records [qo-is-zone.nix:qois.knot.zones.${domain}]

## Invariants

- TXT record data is wrapped in double quotes when rendered [zone-file.nix:renderData]
- The SOA serial in the zone file is always `1`; knot owns the serial via `serial-policy = "dateserial"` [zone-file.nix:renderSoa] [zones.nix:template.default]
- Zone files come from the nix store; `zonefile-sync = -1`, `zonefile-load = "difference-no-serial"`, `journal-content = "all"` keep signatures in the journal [zones.nix:template.default]
- DNSSEC policy `qois`: ecdsap256sha256, `ksk-lifetime = 0` (manual KSK rollover), `zsk-lifetime = "30d"`, NSEC3 with 0 iterations, CDS/CDNSKEY published on rollover, submission checked against 9.9.9.9 and 1.1.1.1 hourly [zones.nix:policy.qois]
- Policy is only attached to zones with `dnssec = true` [zones.nix:zone]
- `vpn.qo.is` is excluded from loadbalancer-derived CNAMEs (served by calanda) [qo-is-zone.nix:serviceNames]
- Zone transfers are authorised by source address (`automatic-acl = true`) [default.nix:server]
- All settings apply only when `qois.knot.enable` is set [default.nix:config] [zones.nix:config]

## Side Effects

- Opens TCP and UDP port 53 in the firewall [default.nix:networking.firewall]
- Enables `services.knot` with `mod-rrl` and `mod-stats` as global modules and syslog logging [default.nix:services.knot]
- Adds the knot state directory (DNSSEC keys, journal) to `qois.backup-client.includePaths` [default.nix:qois.backup-client.includePaths]
- Enables `services.prometheus.exporters.knot` on 127.0.0.1 and scrapes it via `services.telegraf.extraConfig.inputs.prometheus` [default.nix:services.prometheus.exporters.knot]
- Sends NOTIFY to the configured secondaries [zones.nix:zone.notify]

## Verification

- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-knot`
- Run: `nix flake check`
