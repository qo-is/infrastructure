# packages

## Overview

Flake package set. Every subdirectory containing a `default.nix` is auto-discovered and instantiated with `pkgs.callPackage`, exposed as `packages.${system}.<dirname>` [default.nix:genAttrs, foldersWithNix].

## Interface

- Extra arguments passed to every package: `self`, `flakeSelfSpecialUsage`, `system`, `private` [default.nix:callPackage]
- [auto-deploy](./auto-deploy/EGM.md): deploy all nodes of a profile with retries
- [diff-closures](./diff-closures/EGM.md): diff nixosConfiguration closures between git refs
- [docs](./docs/EGM.md): mdBook documentation site
- [grafana-mcp](./grafana-mcp/EGM.md): mcp-grafana wrapper using keyring token
- [qois-disk-unlock](./qois-disk-unlock/EGM.md): unlock encrypted disks via initrd ssh
- [sops](./sops/EGM.md): sops wrapper with generated config
- [sops-config](./sops-config/EGM.md): generated `.sops.yaml`
- [sops-rekey](./sops-rekey/EGM.md): rekey all sops files

## Invariants

- A new package directory needs a `default.nix` to be picked up [default.nix:foldersWithNix]

## Side Effects

- None at evaluation; individual packages are described in their contracts

## Verification

- Run: `nix build .#<pkg>` for a single package, `nix flake check` only evaluates the `packages` output (packages are built only where a host or check depends on them)
