# deploy/system-vm

## Overview

deploy-rs nodes for virtual machine hosts.

## Interface

- Profile `system-vm` on node `<host>`, hostname `<host>.backplane.net.qo.is` [default.nix:nodes, profiles.system-vm]
- Selection: \`services.qemuGuest.enable\` and not \`qois.git-ci-runner.enable\` [default.nix:filterAttrs]
- Settings: `sshUser = "root"`, `user = "root"`, `activationTimeout = 300`, `confirmTimeout = 60`, `remoteBuild = true` [default.nix:profiles.system-vm]
- Payload: `activate.nixos` of the host configuration [default.nix:path]

## Invariants

- Hosts running `qois.git-ci-runner` are never in this category unless it is `system-ci` [default.nix:filterAttrs]

## Side Effects

- None at evaluation; deployment activates the NixOS system on the target

## Verification

- Run: `nix flake check` (deploy-rs checks)
