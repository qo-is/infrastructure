# security-overrides

## Overview

Applies to all hosts: pins selected packages to a specific nixpkgs commit to ship a security fix ahead of the stable channel. Procedure in the legacy [README](./README.md).

## Interface

- `nixpkgsAt { rev, narHash }` imports nixpkgs from a pinned GitHub commit for the host system [default.nix:nixpkgsAt]
- `securityOverride { stable, override, fixedIn, reason }` selects the override package [default.nix:securityOverride]
- Current overrides: `services.nginx.package` (nginxStable, fixed in 1.30.7) and `services.nextcloud.phpPackage` (php84, fixed in 8.4.28) [default.nix:services.nginx.package] [default.nix:services.nextcloud.phpPackage]

## Invariants

- Evaluation throws if `override.version` is older than `fixedIn` [default.nix:securityOverride]
- Evaluation warns if the stable version is at least `fixedIn` (override obsolete) [default.nix:securityOverride]
- `fixedIn = null` disables both checks [default.nix:securityOverride]
- Overrides are set through the service package options, not overlays (documented in README)

## Side Effects

- Fetches nixpkgs revisions via `fetchTree` (hash-pinned) at evaluation time [default.nix:nixpkgsAt]
- Sets `services.nginx.package` and `services.nextcloud.phpPackage` on every host importing the module [default.nix]

## Verification

- Run: `nix flake check`
