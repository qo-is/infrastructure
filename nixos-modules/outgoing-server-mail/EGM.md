# outgoing-server-mail

## Overview

Outbound system mail via msmtp through `mail.cyon.ch`.

## Interface

- `qois.outgoing-server-mail.enable` (bool) [default.nix:options.qois.outgoing-server-mail.enable]

## Invariants

- Uses implicit TLS on port 465 (STARTTLS off) with user `system@qo.is` and sender `no-reply@qo.is` [default.nix:programs.msmtp]
- Local `root` mail is aliased to `sysadmin@qo.is` [default.nix:defaults.aliases]

## Side Effects

- Declares sops secret `msmtp/password` (owner root, group `postdrop`, mode 0440), read by `passwordeval` [default.nix:sops.secrets."msmtp/password"]
- Creates group `postdrop` [default.nix:users.groups.postdrop]
- Enables `programs.msmtp` with `setSendmail = true` [default.nix:programs.msmtp]

## Verification

- Run: `nix flake check`
