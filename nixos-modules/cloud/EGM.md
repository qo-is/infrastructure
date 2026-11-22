# cloud

## Overview

Nextcloud service behind nginx with ACME TLS, PostgreSQL, Redis caching, notify_push and a fixed set of apps. See [legacy README](./README.md) for backup/restore steps.

## Interface

- `qois.cloud.enable` (bool, default false) [default.nix:enable]
- `qois.cloud.domain` (str, default `cloud.qo.is`) [default.nix:domain]
- `qois.cloud.package` (package, no default; relatedPackages nextcloud28/29/30) [default.nix:package]

## Invariants

- App store disabled; apps are declared via `extraApps`: calendar, contacts, deck, groupfolders, memories, music, news, notes, tasks, twofactor_webauthn [default.nix:appstoreEnable, extraApps]
- Admin user `root`, DB type `pgsql` created locally, upload limit 10G, HTTPS and webfinger on [default.nix:services.nextcloud]
- php-fpm pool dynamic with `pm.max_children = 480`; opcache `memory_consumption = 512`, `interned_strings_buffer = 64`, `max_accelerated_files = 50000`, `jit = 1255`, `jit_buffer_size = 8M` [default.nix:poolSettings, phpOptions]
- Mail via `sendmail`, mail domain `qo.is`, default phone region `CH`, logging to syslog tag `nextcloud` [default.nix:settings]

## Side Effects

- sops secret `nextcloud/admin` owned by the `nextcloud` user [default.nix:sops.secrets]
- Enables `services.postgresql`, `services.redis.servers.nextcloud` (log level warning), `services.nextcloud` (with `notify_push`) [default.nix:config]
- Adds nextcloud home to `qois.backup-client.includePaths` [default.nix:qois.backup-client.includePaths]
- Adds `nextcloud` user to group `postdrop` [default.nix:users.users.nextcloud.extraGroups]
- nginx vhost `cfg.domain` with `forceSSL`, `enableACME` [default.nix:services.nginx.virtualHosts]
- telegraf `x509_cert` input for the domain [default.nix:qois.telegraf.serviceInputs.x509_cert]
- Adds `perl` to `nextcloud-cron` path and `nodejs` to system packages (for Recognize) [default.nix:systemd.services.nextcloud-cron, environment.systemPackages]

## Verification

- Run: `nix flake check`
