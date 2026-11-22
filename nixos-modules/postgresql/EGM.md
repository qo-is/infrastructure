# postgresql

## Overview

Shared PostgreSQL defaults: backups, telegraf monitoring, btrfs no-CoW and an opt-in major-version upgrade service. Active only when `services.postgresql.enable` is set by another module. Tested by `test.nix` / `test.py`.

## Interface

- `qois.postgresql.package` (package option for `postgresql`, default null) [default.nix:options.qois.postgresql.package]
- `qois.postgresql.upgradeFrom` (nullable package, default null); when set, enables the `postgresql-upgrade` service [default.nix:options.qois.postgresql.upgradeFrom]
- Systemd units `postgresql-upgrade` and `telegraf-postgresql-setup` [default.nix:systemd.services]

## Invariants

- Config applies if `config.services.postgresql.enable` is true, not on a `qois.postgresql.*` flag [default.nix:config]
- `postgresql-upgrade` runs before and is required by `postgresql.service`, only if `${dataDir}/PG_VERSION` does not exist; runs in a private network and empty `/run/postgresql` [default.nix:systemd.services.postgresql-upgrade]
- The upgrade runs `pg_upgrade` from the old data dir `/var/lib/postgresql/<upgradeFrom.psqlSchema>`, then `vacuumdb --all --analyze-in-stages` [default.nix:script]
- `telegraf-postgresql-setup` runs before `telegraf.service` and after `postgresql.target` [default.nix:systemd.services.telegraf-postgresql-setup]

## Side Effects

- Sets `services.postgresql.package`, `log_checkpoints = false`, ensures user `telegraf` [default.nix:services.postgresql]
- On btrfs root, applies `+C` (no-CoW) to the parent of the data dir via tmpfiles [default.nix:systemd.tmpfiles.settings]
- Enables `services.postgresqlBackup`, adds its location to `qois.backup-client.includePaths`, and registers its service(s) in `qois.telegraf.periodicJobs` [default.nix:services.postgresqlBackup]
- Grants `pg_read_all_stats` to `telegraf` and adds a telegraf `postgresql` service input via `/run/postgresql` [default.nix:qois.telegraf.serviceInputs.postgresql]

## Verification

- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-postgresql`
- Run: `nix flake check`
