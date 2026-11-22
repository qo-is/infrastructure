# kanidm

## Overview

Kanidm identity provider (`id.qo.is`): server, LDAPS, declarative group and OAuth2 client provisioning, domain settings, entry managers, and an optional mail sender for queued messages such as credential resets. Persons are not provisioned from code. See [legacy README](./README.md) for user setup, secrets commands, administration and restore. Relying parties attach through [kanidm-relying-party](../kanidm-relying-party/EGM.md).

## Interface

- `qois.kanidm.enable` (bool, default false) [default.nix:enable]
- `qois.kanidm.domain` (str, default `id.qo.is`) [default.nix:domain]
- `qois.kanidm.package` (package, required; must support secret provisioning) [default.nix:package]
- `qois.kanidm.port` (port, default 8443) [default.nix:port]
- `qois.kanidm.ldapPort` (port, default 636) [default.nix:ldapPort]
- `qois.kanidm.secretsFile` (path; set by `secrets.nix` to `private/nixos-modules/kanidm/<hostName>.sops.yaml`) [default.nix:secretsFile, secrets.nix]
- `qois.kanidm.adminPasswordFile`, `qois.kanidm.idmAdminPasswordFile` (path, default sops `kanidm/admin-password`, `kanidm/idm-admin-password`) [default.nix]
- `qois.kanidm.groups` (attrsOf (listOf str), default `{}`; `sysadmin` and `idm_admins` always set) [default.nix:groups]
- `qois.kanidm.oauth2Clients.<name>` with `displayName`, `originUrl` (str or nonEmptyListOf str), `originLanding`, `scopes` (default openid/email/profile), `roles`, `roleClaim` (default `groups`), `secretFile`, `settings` [default.nix:oauth2Clients]
- `qois.kanidm.displayName` (str, default domain), `qois.kanidm.allowAccountRecovery` (bool, default `mailSender.enable`) [domain-settings.nix]
- `qois.kanidm.groupEntryManagers` (attrsOf str, default `{ sysadmin = "idm_admins"; }`) [entry-managers.nix]
- `qois.kanidm.mailSender.{enable,instanceDisplayName,relay,username,passwordFile,fromAddress,replyToAddress}`; `enable` defaults to `qois.outgoing-server-mail.enable`, `replyToAddress` to `sysadmin@qo.is`, others derive from msmtp [mail-sender.nix]
- Helper scripts: `kanidm-api.sh` (authenticate/api helpers), `domain-settings.sh`, `entry-managers.sh`, `mail-sender-token.sh`, `mail-sender-config.sh` [\*.sh]

## Invariants

- Server binds `[::1]:port` (HTTPS) behind nginx and `[::]:ldapPort` (LDAPS; not opened in the firewall) [default.nix:bindaddress, ldapbindaddress]
- Group members are provisioned with `overwriteMembers = false` (appended), and each client gets `<name>.access` holding its role groups [default.nix:appendedGroup, clientGroups]
- OAuth2: `preferShortUsername = true`, scope map on the `.access` group, claim map `roleClaim` from `roles` [default.nix:clientOauth2]
- Online backups keep 2 versions [default.nix:online_backup.versions]
- TLS chain and key are copied from the ACME cert into the kanidm state dir (mode 0400) in `postRun` [default.nix:security.acme.certs.postRun]
- Domain settings and entry managers are applied idempotently in `ExecStartPost` of `kanidm.service`; entry-manager updates detach the group from its parents while setting `entry_managed_by` [domain-settings.nix, entry-managers.sh:set_entry_manager]
- Mail sender token is validated via `/v1/auth/valid`; regenerated (old labelled tokens revoked) only if rejected or missing, and the `mail-sender` account is added to `idm_message_senders` [mail-sender-token.sh]
- Mail sender service is sandboxed (`DynamicUser`, empty capability set, syscall filter) and receives token and mail password via `LoadCredential` [mail-sender.nix:systemd.services.kanidm-mail-sender]

## Side Effects

- Enables `services.kanidm` server, client and provisioning [default.nix:services.kanidm]
- sops secrets `kanidm/admin-password`, `kanidm/idm-admin-password` owned by `kanidm` [default.nix:sops.secrets]
- `kanidm.service` ordered after and wants `acme-order-renew-<domain>.service`; log filter patterns drop noisy lines [default.nix:systemd.services.kanidm]
- ACME cert for the domain, reload of `kanidm.service` [default.nix:security.acme.certs]
- State dir added to backup paths [default.nix:qois.backup-client.includePaths]
- telegraf `http_response` on `/status` and `x509_cert` inputs [default.nix:qois.telegraf.serviceInputs]
- nginx vhost proxying to `https://[::1]:port`; `networking.hosts."127.0.0.1"` for the domain [default.nix:services.nginx]
- When mailer is enabled: hourly oneshot `kanidm-mail-sender-token.service`, path unit `kanidm-mail-sender-token-changed` that try-restarts `kanidm-mail-sender.service`, and long-running `kanidm-mail-sender.service` [mail-sender.nix]
- HTTP calls to the kanidm API at `provision.instanceUrl` [kanidm-api.sh]

## Verification

- Run: `nix flake check`
- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-kanidm` (test in `./test.nix`, `./test.py`)
