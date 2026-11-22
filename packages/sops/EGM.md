# sops

## Overview

`sops` wrapper that first builds the generated `.sops.yaml` and then runs sops with it.

## Interface

- Derivation `sops`, description "Run SOPS with the generated configuration" [default.nix:writeShellApplication]
- CLI: all arguments are forwarded to `sops --config <FLAKE_ROOT>/.sops.yaml` [default.nix:text]
- Runtime deps: `sops`, `gitMinimal`, `nix` [default.nix:runtimeInputs]
- Depends on the [sops-config](../sops-config/EGM.md) flake package

## Invariants

- The config is always regenerated from `#sops-config` before sops runs [default.nix:text]

## Side Effects

- Writes the out-link `<FLAKE_ROOT>/.sops.yaml` [default.nix:nix build --out-link]

## Verification

- Run: `nix build .#sops`
