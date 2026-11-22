# nginx

## Overview

Shared nginx defaults for all hosts, plus optional PROXY protocol handling when the host sits behind the [loadbalancer](../loadbalancer/EGM.md). It does not enable nginx itself.

## Interface

- `qois.nginx.behindLoadbalancer` (enable option) [default.nix:options.qois.nginx.behindLoadbalancer]

## Invariants

- Trusted proxies are the backplane IPs of `lindberg` and `cyprianspitz` [default.nix:loadbalancerHosts]
- With `behindLoadbalancer`, public listeners (0.0.0.0 and, if IPv6 is enabled, `[::0]`) require the PROXY protocol while loopback listeners do not; `set_real_ip_from` and `real_ip_header proxy_protocol` are emitted [default.nix:defaultListen] [default.nix:appendHttpConfig]
- `statusPage` follows `services.nginx.enable` [default.nix:statusPage]

## Side Effects

- Sets recommended TLS, optimisation, proxy, gzip and brotli settings, `logError = "stderr error"`, `proxyResolveWhileRunning`, and `log_not_found off;` on `services.nginx` (applied regardless of the option) [default.nix:services.nginx]

## Verification

- Run: `nix flake check`
