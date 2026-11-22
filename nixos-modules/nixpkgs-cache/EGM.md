# nixpkgs-cache

## Overview

Caching reverse proxy for `cache.nixos.org` served via nginx with ACME TLS.

## Interface

- `qois.nixpkgs-cache.enable` (bool) [default.nix:options.qois.nixpkgs-cache.enable]
- `qois.nixpkgs-cache.hostname` (str, default `nixpkgs-cache.qo.is`) [default.nix:options.qois.nixpkgs-cache.hostname]
- `qois.nixpkgs-cache.timeout` (str, default `"90d"`) [default.nix:options.qois.nixpkgs-cache.timeout]
- `qois.nixpkgs-cache.size` (int GB, default 50) [default.nix:options.qois.nixpkgs-cache.size]
- `qois.nixpkgs-cache.dnsResolvers` (listOf str, required) [default.nix:options.qois.nixpkgs-cache.dnsResolvers]

## Invariants

- IPv6 resolution is disabled in nginx (TODO(6)) [default.nix:resolver.ipv6]
- Key zone size is `size * 3` MB [default.nix:keysZoneSize]
- Upstream TLS is verified against `/etc/ssl/certs/ca-certificates.crt`; upstream cache headers are ignored since objects are immutable [default.nix:locations]
- The cache is currently not configured as a substituter in [system](../system/EGM.md) (commented out) [../system/default.nix:substituters]

## Side Effects

- Maps the hostname to 127.0.0.1 in `networking.hosts` [default.nix:networking.hosts]
- Enables nginx with a `proxyCachePath` and a `forceSSL`/`enableACME` virtual host proxying to `https://cache.nixos.org` [default.nix:services.nginx]

## Verification

- Run: `nix flake check`
