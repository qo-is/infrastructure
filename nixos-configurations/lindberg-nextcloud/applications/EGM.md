# lindberg-nextcloud applications

## Overview

Nextcloud service configuration for the lindberg-nextcloud VM.

## Interface

- `qois.cloud` enabled with `package = pkgs.nextcloud34` [default.nix:qois.cloud].
- `qois.nginx.behindLoadbalancer = true` [default.nix].
- PostgreSQL: `postgresql_18`, `upgradeFrom = postgresql_14` [default.nix:qois.postgresql].

## Invariants

- PostgreSQL upgrade source version must match the existing data [default.nix:qois.postgresql.upgradeFrom].

## Side Effects

- Runs Nextcloud and PostgreSQL; see [Nextcloud](../../../nixos-modules/cloud/README.md).

## Verification

- Build: `nix build .#nixosConfigurations.lindberg-nextcloud.config.system.build.toplevel`
- All: `nix flake check`
