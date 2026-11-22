# prometheus

## Overview

Main Prometheus server scraping telegraf on all hosts. Legacy notes (web UI, oauth2-proxy cookie secret, storage) in [README](./README.md). Tested by `test.nix` / `test.py`.

## Interface

- `qois.prometheus.enable` (bool) [default.nix:options.qois.prometheus.enable]
- `qois.prometheus.domain` (str, default `prometheus.qo.is`) [default.nix:options.qois.prometheus.domain]
- Imports `inputs.srvos.nixosModules.roles-prometheus` [default.nix:imports]

## Invariants

- Scrape jobs: `prometheus` (local), `telegraf` (port 9273 on the six backplane hosts calanda, cyprianspitz, lindberg, lindberg-build, lindberg-nextcloud, lindberg-webapps), and `loki` only when `qois.loki.enable` [default.nix:scrapeConfigs]
- Retention 31d, log level warn, `checkConfig = true` [default.nix:services.prometheus]
- Data is not backed up (see README)

## Side Effects

- Enables `services.prometheus` with `webExternalUrl = https://<domain>/` [default.nix:services.prometheus]
- Defaults `qois.telegraf.monitoring.enable` to true [default.nix:qois.telegraf.monitoring.enable]

## Verification

- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-prometheus`
- Run: `nix flake check`
