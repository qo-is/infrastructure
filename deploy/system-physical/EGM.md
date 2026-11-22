# deploy/system-physical

## Overview

deploy-rs nodes for physical hosts.

## Interface

- Profile `system-physical` on node `<host>`, hostname `<host>.backplane.net.qo.is` [default.nix:nodes, profiles.system-physical]
- Selection: not `services.qemuGuest.enable` and not `qois.git-ci-runner.enable` [default.nix:filterAttrs]
- Settings: `sshUser = "root"`, `user = "root"`, `activationTimeout = 600`, `confirmTimeout = 120`, `remoteBuild = true` [default.nix:profiles.system-physical]
- Payload: `activate.nixos` of the host configuration [default.nix:path]

## Invariants

- Hosts with `qois.git-ci-runner.enable` are never in this category [default.nix:filterAttrs]

## Side Effects

- None at evaluation; deployment activates the NixOS system on the target

## Verification

- Run: `nix flake check` (deploy-rs checks)
