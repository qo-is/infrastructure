# lindberg-webapps applications

## Overview

Web applications and monitoring stack on the webapps VM. Legacy notes on setting up static site deploy keys: [README.md](./README.md).

## Interface

- `qois.nginx.behindLoadbalancer = true` [default.nix].
- Enabled: `qois.vault`, `qois.git`, `qois.kanidm` (package `kanidmWithSecretProvisioning_1_11`), `qois.kanidm-grafana`, `qois.kanidm-forgejo`, `qois.kanidm-prometheus`, `qois.static-page` [default.nix].
- Monitoring: `qois.prometheus`, `qois.grafana`, `qois.loki`, `qois.alertmanager` [default.nix].
- PostgreSQL: `postgresql_18`, `upgradeFrom = postgresql_15` [default.nix:qois.postgresql].

## Invariants

- PostgreSQL upgrade source version must match the existing data [default.nix:qois.postgresql.upgradeFrom].

## Side Effects

- Runs identity, git hosting, password vault, static sites and observability services.

## Verification

- Build: `nix build .#nixosConfigurations.lindberg-webapps.config.system.build.toplevel`
- All: `nix flake check`
