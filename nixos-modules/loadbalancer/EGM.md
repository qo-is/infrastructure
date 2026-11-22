# loadbalancer

## Overview

HAProxy based HTTP/HTTPS (SNI) loadbalancer that maps domains to backend hosts on the backplane network. Tested by `test.nix` / `test.py`.

## Interface

- `qois.loadbalancer.enable` (bool) [default.nix:options.qois.loadbalancer.enable]
- `qois.loadbalancer.domains` (attrsOf str, domain to backend hostname; default static pages mapped to `lindberg-webapps` plus fixed service mappings such as `cloud.qo.is`, `git.qo.is`, `vpn.qo.is`) [default.nix:defaultDomains]
- `qois.loadbalancer.hostmap` (attrsOf str, hostname to IP; default backplane IPs of lindberg-nextcloud, lindberg-build, lindberg-webapps, cyprianspitz) [default.nix:defaultHostmap]
- `qois.loadbalancer.extraConfig` (nullOr lines, default backends for lindberg-rzimmermann, cyprianspitz-nginx and workstations-9001) [default.nix:defaultExtraConfig]

## Invariants

- Static pages from `qois.static-page.pages` (domain and aliases) are assumed to be hosted on `lindberg-webapps` [default.nix:staticPages]
- Each hostmap entry generates `<name>-https` (tcp, port 443, `send-proxy-v2`) and `<name>-http` (http, port 80, `send-proxy-v2`) backends [default.nix:genHttpBackend]
- Frontend `http` routes by lowercase Host header, frontend `https` by lowercase SNI, both via a generated map file [default.nix:services.haproxy.config]
- Stats and Prometheus endpoint bind only to `127.0.0.1:8404` [default.nix:statsIpPort]
- Everything applies only when enabled [default.nix:config]

## Side Effects

- Opens TCP 80 and 443 in the firewall [default.nix:networking.firewall.allowedTCPPorts]
- Enables `services.haproxy` with the generated config [default.nix:services.haproxy]
- Adds a telegraf `prometheus` service input scraping `http://127.0.0.1:8404/metrics` [default.nix:qois.telegraf.serviceInputs.prometheus]

## Verification

- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-loadbalancer`
- Run: `nix flake check`
