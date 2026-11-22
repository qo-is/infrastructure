# backplane-net.hosts

## Overview

Adds `/etc/hosts` aliases that resolve loadbalanced service domains to the backplane IP of the loadbalancer host, avoiding detours over external networks.

## Interface

- `qois.backplane-net.hosts.enable` (bool, default **true**) [default.nix:enable]
- `qois.backplane-net.hosts.domains` (listOf str, default `attrNames config.qois.loadbalancer.domains`) [default.nix:domains]
- `qois.backplane-net.hosts.loadbalancers` (listOf str, default `[ "lindberg" ]`) [default.nix:loadbalancers]
- Parent module: [backplane-net](../backplane-net/EGM.md)

## Invariants

- Each loadbalancer name must exist in `qois.meta.network.virtual.backplane.hosts` (its `v4.ip` is used) [default.nix:networking.hosts]
- Defaults depend on option `qois.loadbalancer.domains` existing [default.nix:defaultDomains]

## Side Effects

- Sets `networking.hosts` mapping each loadbalancer IP to all `domains` [default.nix:networking.hosts]

## Verification

- Run: `nix flake check`
