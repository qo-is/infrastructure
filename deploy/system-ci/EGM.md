# deploy/system-ci

## Overview

deploy-rs nodes for hosts that run the CI runner.

## Interface

- Profile `system-ci` on node `<host>`, hostname `<host>.backplane.net.qo.is` [default.nix:nodes, profiles.system-ci]
- Selection: `qois.git-ci-runner.enable` [default.nix:filterAttrs]
- Settings: `sshUser = "root"`, `user = "root"`, `activationTimeout = 300`, `confirmTimeout = 60`, `remoteBuild = true` [default.nix:profiles.system-ci]
- Payload: `activate.nixos` of the host configuration [default.nix:path]

## Invariants

- Membership is exactly `qois.git-ci-runner.enable`, regardless of `services.qemuGuest.enable` [default.nix:filterAttrs]

## Side Effects

- None at evaluation; deployment activates the NixOS system on the target

## Verification

- Run: `nix flake check` (deploy-rs checks)
