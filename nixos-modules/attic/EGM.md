# attic

## Overview

Attic Nix binary cache server (`atticd`) backed by PostgreSQL and served through nginx with ACME TLS. Cache availability is best effort; artifacts are not backed up.

## Interface

- `qois.attic.enable` (bool, default false) [default.nix:enable]
- `qois.attic.domain` (str, default `attic.qo.is`) [default.nix:domain]
- `qois.attic.port` (`types.numbers.between 1 65536`, default 8080) [default.nix:port]

## Invariants

- atticd listens on `127.0.0.1:${port}`, allows only host `cfg.domain`, API endpoint `https://${domain}/` [default.nix:settings.listen, allowed-hosts, api-endpoint]
- Chunking: threshold 64 KiB, min 16 KiB, avg 64 KiB, max 256 KiB; changing them reduces deduplication [default.nix:settings.chunking]
- Default GC retention is 6 months [default.nix:garbage-collection.default-retention-period]
- Database is PostgreSQL over the unix socket `/run/postgresql`, database/user `atticd` [default.nix:database.url, services.postgresql]
- No backup paths are registered [default.nix:comment "best effort"]

## Side Effects

- sops secret `attic/server_token` (restarts `atticd.service`) used as `environmentFile` [default.nix:sops.secrets, services.atticd.environmentFile]
- Enables `services.atticd`, `services.postgresql` (ensureDatabases/ensureUsers `atticd`) [default.nix:config]
- nginx virtual host `cfg.domain` with `forceSSL`, `enableACME`, proxy to localhost port; global `clientMaxBodySize = "10G"` [default.nix:services.nginx]
- Adds a telegraf `x509_cert` input for `https://${domain}:443` [default.nix:qois.telegraf.serviceInputs.x509_cert]

## Verification

- Run: `nix flake check`
