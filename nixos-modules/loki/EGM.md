# loki

## Overview

Single-node Loki log aggregation with filesystem storage and retention. Receives logs from [vector](../vector/EGM.md). Tested by `test.nix` / `test.py`.

## Interface

- `qois.loki.enable` (bool) [default.nix:options.qois.loki.enable]
- `qois.loki.port` (port, default 3100) [default.nix:options.qois.loki.port]
- `qois.loki.retentionPeriod` (str, default `"744h"`) [default.nix:options.qois.loki.retentionPeriod]

## Invariants

- Authentication is disabled (`auth_enabled = false`); access is limited by the firewall to `wg-backplane` [default.nix:configuration] [default.nix:networking.firewall.interfaces]
- Replication factor 1, in-memory ring, TSDB schema v13 from 2024-01-01 on the filesystem [default.nix:common] [default.nix:schema_config]
- Samples older than 168h are rejected [default.nix:limits_config]
- Retention is enforced by the compactor [default.nix:compactor]

## Side Effects

- Opens `cfg.port` TCP on interface `wg-backplane` [default.nix:networking.firewall.interfaces]
- Enables `services.loki`, storing data under `/var/lib/loki` [default.nix:services.loki]

## Verification

- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-loki`
- Run: `nix flake check`
