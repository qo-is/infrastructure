# checks/nixos-modules

## Overview

Generates a NixOS VM test for every module in `nixos-modules/` that has a `test.nix`.

## Interface

- Derivation `nixos-modules` via `linkFarmFromDrvs` of tests named after the module directory [default.nix:linkFarmFromDrvs]
- Flake attribute `checks.${system}.nixos-modules` [../default.nix:nixos-modules]
- Per module inputs: `nixos-modules/<name>/test.nix` and `test.py` [default.nix:mkTest, testScript]
- Test option `args` (attrsOf str) to pass extra string arguments to the python `test(...)` function [default.nix:args]
- Python entry point `test(<nodes...>, <args...>, subtest=subtest)` [default.nix:testScript]

## Invariants

- Test nodes import `defaultModule` and set `qois.outgoing-server-mail.enable`, `qois.backup-client.enable` and `services.btrfs.autoScrub.enable` to `mkForce false`, `qois.vector.enable = false`, and `qois.telegraf.enable = mkOverride 75 false` so tests can opt back in [default.nix:defaults]
- Node arguments are passed as Python variable references unless overridden by `args` [default.nix:nodeRefArgs]

## Side Effects

- Requires QEMU/KVM to run [./../README.md]

## Verification

- Run: `nix build .#checks.x86_64-linux.nixos-modules`
- Single test: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-<name>`
