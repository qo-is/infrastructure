# checks/packages

## Overview

Check definition that builds all packages. Not currently wired into the checks output.

## Interface

- Derivation `all` via `linkFarmFromDrvs` of `attrValues self.packages` [default.nix:linkFarmFromDrvs]

## Invariants

- `../default.nix` does not import this directory, so no `checks.${system}.packages` attribute exists [../default.nix]
- `self.packages` is keyed by system, so `attrValues` yields per-system sets rather than derivations [default.nix:attrValues]

## Side Effects

- None

## Verification

- Run: `nix build .#<pkg>` per package
