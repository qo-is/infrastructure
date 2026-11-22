# kanidm-prometheus

## Overview

Protects the Prometheus and Alertmanager web UIs with kanidm SSO through oauth2-proxy and nginx `auth_request`. Uses [kanidm-relying-party](../kanidm-relying-party/EGM.md).

## Interface

- `qois.kanidm-prometheus.enable` (bool, default false) [default.nix:enable]
- Declares `qois.kanidm-relying-party.prometheus` with redirect `https://<qois.prometheus.domain>/oauth2/callback`, role `sysadmin` mapped to `PrometheusAdmin` [default.nix:qois.kanidm-relying-party.prometheus]

## Invariants

- Only members whose claim contains `PrometheusAdmin` are allowed [default.nix:allowed_groups, accessRole]
- oauth2-proxy: OIDC issuer from kanidm, PKCE `S256`, cookie expiry 24h, trusted proxies loopback, `whitelist-domain` = prometheus domain [default.nix:services.oauth2-proxy]
- nginx uses `proxy_pass` via `extraConfig` (not `proxyPass`) to avoid the `$nix_proxy_target` overwrite by the auth subrequest [default.nix:proxyTo]
- Alertmanager UI is proxied at `qois.alertmanager.routePrefix/` only if alertmanager is enabled [default.nix:optionalAttrs]
- oauth2-proxy restarts every 5s with unlimited start attempts until OIDC discovery works [default.nix:RestartSec, StartLimitIntervalSec]

## Side Effects

- sops secret `oauth2-proxy/cookie-secret` (restarts `oauth2-proxy.service`) [default.nix:sops.secrets]
- Orders `oauth2-proxy.service` after `kanidm.service` and `nginx.service` when kanidm is local [default.nix]
- nginx vhost for the prometheus domain with `forceSSL`, `enableACME`; `networking.hosts` loopback entry [default.nix:services.nginx, networking.hosts]
- telegraf `x509_cert` input [default.nix:qois.telegraf.serviceInputs.x509_cert]

## Verification

- Run: `nix flake check`
- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-kanidm-prometheus` (test in `./test.nix`, `./test.py`)
