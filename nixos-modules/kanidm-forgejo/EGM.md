# kanidm-forgejo

## Overview

Forgejo single sign-on through kanidm. Declares the `forgejo` relying party and registers the OpenID Connect login source in Forgejo on every start. Consumes [kanidm-relying-party](../kanidm-relying-party/EGM.md), [kanidm](../kanidm/EGM.md) and [git](../git/EGM.md).

## Interface

- `qois.kanidm-forgejo.enable` (bool, default false) [default.nix:enable]
- Declares `qois.kanidm-relying-party.forgejo` with redirect `https://<git.domain>/user/oauth2/kanidm/callback` and roles `sysadmin`, `forgejo-users`, `forgejo-qois` [default.nix:qois.kanidm-relying-party.forgejo]
- Script `forgejo-register-kanidm` (add or update the login source named `kanidm`) [default.nix:registerSource]

## Invariants

- Login source name is `kanidm`, admin group `sysadmin`, group claim `groups`, team map `forgejo-qois` to `Owners` of org `qo.is` with removal [default.nix:sourceName, adminGroup, groupTeamMap]
- Local 2FA is skipped for the source [default.nix:--skip-local-2fa]
- Registration failure only warns, so Forgejo starts with the stored source if kanidm is unreachable [default.nix:preStart]
- `ACCOUNT_LINKING = "auto"` links accounts by email; safe only while persons cannot set their own email in kanidm [default.nix:oauth2_client]
- Kanidm side adds group `forgejo-qois` containing `sysadmin` [default.nix:qois.kanidm.groups]

## Side Effects

- Appends `registerSource` to `forgejo.service` preStart, which curls the discovery URL (retries) and runs `forgejo admin auth` [default.nix:systemd.services.forgejo.preStart]
- Orders `forgejo.service` after `kanidm.service` and `nginx.service` when kanidm is local [default.nix:mkIf kanidm.enable]
- Sets `services.forgejo.settings.oauth2_client` (auto registration, username from `preferred_username`) [default.nix]

## Verification

- Run: `nix flake check`
- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-kanidm-forgejo` (test in `./test.nix`, `./test.py`)
