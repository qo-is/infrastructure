# checks/packages

## Overview

Check that builds every package of the current system.

## Interface

- `checks.${system}.packages`: derivation `all-packages` via `linkFarmFromDrvs` of `attrValues self.packages.${system}` [default.nix:linkFarmFromDrvs]

## Invariants

- Imported by `../default.nix` [../default.nix:packages]

## Side Effects

- None

## Verification

- Run: `nix build .#checks.x86_64-linux.packages`
