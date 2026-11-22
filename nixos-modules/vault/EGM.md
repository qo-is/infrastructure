# vault

## Overview

Vaultwarden (Bitwarden-compatible) password server with PostgreSQL backend behind nginx. Operations (accounts, admin panel, restore) in the legacy [README](./README.md). Tested by `test.nix` / `test.py`.

## Interface

- `qois.vault.enable` (bool) [default.nix:options.qois.vault.enable]
- `qois.vault.domain` (str, default `vault.qo.is`) [default.nix:options.qois.vault.domain]
- `qois.vault.environmentFile` (as `services.vaultwarden.environmentFile`; defaults to sops secret `vaultwarden/environment-file` path if declared) [default.nix:options.qois.vault.environmentFile]

## Invariants

- Signups, invitations and email change are disabled; signups whitelist domain `qo.is`; verification on [default.nix:services.vaultwarden.config]
- Mail is sent through `msmtp` sendmail from `vault@qo.is` [default.nix:SENDMAIL_COMMAND]
- Data folder is `/var/lib/vaultwarden`, trash is purged after 30 days [default.nix:DATA_FOLDER] [default.nix:TRASH_AUTO_DELETE_DAYS]

## Side Effects

- Enables `services.vaultwarden` with `dbBackend = "postgresql"`, `configureNginx` and `configurePostgres` [default.nix:services.vaultwarden]
- Sops secret `vaultwarden/environment-file` restarts `vaultwarden.service` [default.nix:sops.secrets]
- Adds user `vaultwarden` to group `postdrop` (see [outgoing-server-mail](../outgoing-server-mail/EGM.md)) [default.nix:users.users.vaultwarden]
- Adds the data folder to `qois.backup-client.includePaths` [default.nix:qois.backup-client.includePaths]
- Maps the domain to 127.0.0.1, enables ACME on its nginx virtual host, adds a telegraf `x509_cert` input [default.nix:services.nginx.virtualHosts] [default.nix:qois.telegraf.serviceInputs]

## Verification

- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-vault`
- Run: `nix flake check`
