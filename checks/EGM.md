# checks

## Overview

Flake `checks.${system}` output. See the legacy [README](./README.md) for the NixOS test workflow and hints for writing tests.

## Subdirectories & Boundaries

- nixos-configurations: [./nixos-configurations/EGM.md](./nixos-configurations/EGM.md) - builds all hosts
- nixos-modules: [./nixos-modules/EGM.md](./nixos-modules/EGM.md) - per-module NixOS VM tests
- packages: [./packages/EGM.md](./packages/EGM.md) - builds all packages

## Interface

- `checks.${system}.formatting`: treefmt check using `treefmt.nix` [default.nix:formatting]
- `checks.${system}.nixos-modules` [default.nix:nixos-modules]
- `checks.${system}.nixos-configurations` [default.nix:nixos-configurations]
- `checks.${system}.packages`: links every `packages.${system}` derivation [default.nix:packages]
- `checks.${system}.topology`: topology output [default.nix:topology]
- Per-node deploy-rs checks from `deployChecks self.deploy` [default.nix:deployChecks]

## Side Effects

- NixOS tests need QEMU/KVM [./README.md]

## Verification

- Run: `nix flake check`
