# lindberg-build applications

## Overview

CI runner, Attic cache, Renovate and the (disabled) nixpkgs cache on the build VM. Legacy notes on cache usage and Attic administration: [README.md](./README.md).

## Interface

- `qois.nginx.behindLoadbalancer = true`; `qois.git-ci-runner.enable = true` with `nixInstances = 3`; `qois.attic.enable`; `qois.renovate.enable` [default.nix].
- PostgreSQL: package `postgresql_18`, `upgradeFrom = postgresql_15` [default.nix:qois.postgresql].
- `nix.settings.substituters = mkForce [ "https://cache.nixos.org?priority=40" ]` [default.nix].
- `qois.nixpkgs-cache` with `enable = false` and `dnsResolvers` set to lindberg's `vms-nat` IP [nixpkgs-cache.nix].

## Invariants

- Substituters hosted on this node are removed to avoid lockups [default.nix:nix.settings.substituters].
- nixpkgs cache stays disabled (TLS errors proxying to cache.nixos.org) [nixpkgs-cache.nix:enable].

## Side Effects

- Runs CI jobs, a Postgres database and Attic cache server.

## Verification

- Build: `nix build .#nixosConfigurations.lindberg-build.config.system.build.toplevel`
- All: `nix flake check`
