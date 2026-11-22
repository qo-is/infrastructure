# grafana

## Overview

Grafana behind nginx with TLS, PostgreSQL storage, and provisioned Prometheus/Loki/Alertmanager datasources. Dashboards are git-synced (declarative Grafana provisioning repository in `./git-sync/repository.yaml`). See [legacy README](./README.md) for user setup, secrets and git-sync deployment. SSO is added by [kanidm-grafana](../kanidm-grafana/EGM.md).

## Interface

- `qois.grafana.enable` (bool, default false) [default.nix:enable]
- `qois.grafana.domain` (str, default `monitoring.qo.is`) [default.nix:domain]
- `qois.grafana.bind_ip` (str, default `127.0.0.1`) [default.nix:bind_ip]
- `qois.grafana.port` (port, default 3000) [default.nix:port]
- Datasources (conditional on the service being enabled): Prometheus (uid `PBFA97CFB590B2093`, default), Loki (uid `P8E80F9AEF21F6940`), Alertmanager (uid `P1D6A1A3E0C9B7F42`) [default.nix:provision.datasources]

## Invariants

- `enforce_domain = true`; anonymous auth disabled; Gravatar, analytics and update checks disabled [default.nix:settings]
- Admin user/password and `secret_key` are read via `$__file{...}` from sops secrets [default.nix:settings.security]
- Database is PostgreSQL via `/run/postgresql`, name/user `grafana` [default.nix:settings.database, services.postgresql]
- Provisioning repository types `git|local`, allowed git URLs `git.qo.is` [default.nix:settings.provisioning]
- Alertmanager datasource has `handleGrafanaManagedAlerts = false` and uses `qois.alertmanager.routePrefix` [default.nix:Alertmanager datasource]

## Side Effects

- sops secrets `grafana/admin/user`, `grafana/admin/password`, `grafana/secret_key` (owned by grafana, restart `grafana.service`) [default.nix:sops.secrets]
- Enables `services.grafana`, `services.postgresql` with ensured DB/user [default.nix:config]
- nginx vhost with `forceSSL`, `enableACME`, websockets proxy to `bind_ip:port` [default.nix:services.nginx]
- `networking.hosts."127.0.0.1"` for the domain [default.nix:networking.hosts]
- telegraf `x509_cert` input [default.nix:qois.telegraf.serviceInputs.x509_cert]

## Verification

- Run: `nix flake check`
- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-grafana` (test in `./test.nix`, `./test.py`)
