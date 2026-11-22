# deploy

## Overview

Flake `deploy` output for deploy-rs. Each subdirectory with a `default.nix` is auto-loaded via `loadSubmodulesFrom` and merged with `recursiveUpdate` [default.nix:pipe]. See also the legacy [README](./README.md) for the deployment commands and category explanation.

## Subdirectories & Boundaries

- docs-ops: [./docs-ops/EGM.md](./docs-ops/EGM.md) - docs site profile on `lindberg-webapps`
- system-ci: [./system-ci/EGM.md](./system-ci/EGM.md) - hosts with the git CI runner, own category so they do not break automated deploys
- system-physical: [./system-physical/EGM.md](./system-physical/EGM.md) - non-VM, non-CI hosts
- system-vm: [./system-vm/EGM.md](./system-vm/EGM.md) - qemu guest hosts, non-CI

## Interface

- Output attrs: `nodes.<host>.profiles.<category>` with categories `system-ci`, `system-physical`, `system-vm` and `docs-ops.qo.is` [default.nix:foldl recursiveUpdate]
- Usage: `auto-deploy <category>` or `deploy --skip-checks .#<host>.<category>` [./README.md]

## Invariants

- Categories are disjoint: ci, vm and physical are partitioned by `qois.git-ci-runner.enable` and `services.qemuGuest.enable` [system-\*/default.nix:filterAttrs]

## Side Effects

- None at evaluation; deployment requires VPN or backplane access and root SSH [./README.md]

## Verification

- Run: `nix flake check` (includes `deployChecks`, see [checks](../checks/EGM.md))
