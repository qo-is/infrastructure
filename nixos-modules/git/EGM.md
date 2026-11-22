# git

## Overview

Forgejo git hosting at `git.qo.is` with PostgreSQL, LFS, sendmail (msmtp) notifications and nginx. SSO is wired by [kanidm-forgejo](../kanidm-forgejo/EGM.md). See [legacy README](./README.md).

## Interface

- `qois.git.enable` (bool, default false) [default.nix:enable]
- `qois.git.domain` (str, default `git.qo.is`) [default.nix:domain]
- `qois.git.msmtpPasswordFile` (path; default `sops.secrets."msmtp/password".path` only if that secret is declared, otherwise no default) [default.nix:msmtpPasswordFile]

## Invariants

- Forgejo serves over a unix socket (`PROTOCOL = http+unix`); SSH is disabled; registration disabled; secure cookies [default.nix:settings.server, service, session]
- Mailer is `sendmail` via `msmtp` with `--passwordeval 'cat <file>'`, from `git@qo.is` [default.nix:settings.mailer]
- Metrics enabled; nginx `/metrics` allows only `127.0.0.1/24` and `10.250.0.0/24` [default.nix:metrics.ENABLED, locations."/metrics"]
- nginx `client_max_body_size 512M`; websockets proxied on `/` [default.nix:virtualHosts]
- RSA minimum key size 2047 [default.nix:"ssh.minimum_key_sizes"]

## Side Effects

- Enables `services.postgresql`, `services.forgejo` (LFS) [default.nix:config]
- Adds Forgejo stateDir to backup paths [default.nix:qois.backup-client.includePaths]
- Adds `forgejo` user to `postdrop`; password file is `ReadOnlyPaths` of `forgejo.service` [default.nix:users.users.forgejo, systemd.services.forgejo]
- telegraf `prometheus` input on `https://<domain>/metrics` and `x509_cert` input [default.nix:qois.telegraf.serviceInputs]
- `networking.hosts."127.0.0.1"` maps the domain to localhost [default.nix:networking.hosts]
- nginx vhost with `forceSSL`, `enableACME` [default.nix:services.nginx]

## Verification

- Run: `nix flake check`
- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-git` (test in `./test.nix`, `./test.py`)
