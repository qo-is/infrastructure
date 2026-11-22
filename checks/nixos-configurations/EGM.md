# checks/nixos-configurations

## Overview

Check that builds every host configuration.

## Interface

- Derivation `all` via `linkFarmFromDrvs` of every `nixosConfigurations.*.config.system.build.toplevel` [default.nix:linkFarmFromDrvs]
- Flake attribute `checks.${system}.nixos-configurations` [../default.nix:nixos-configurations]

## Invariants

- Covers all of `self.nixosConfigurations` [default.nix:mapAttrsToList]

## Side Effects

- None

## Verification

- Run: `nix build .#checks.x86_64-linux.nixos-configurations`
