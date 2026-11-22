# networkd

## Overview

Switch for systemd-networkd with systemd-resolved.

## Interface

- `qois.networkd.enable` (bool) [default.nix:options.qois.networkd.enable]

## Invariants

- `networking.useNetworkd` always follows the option value, so it is explicitly false when disabled [default.nix:networking.useNetworkd]
- LLMNR is disabled and fallback DNS is dns.switch.ch (130.59.31.248, 130.59.31.251) [default.nix:services.resolved]

## Side Effects

- When enabled, enables `services.resolved` [default.nix:services.resolved]

## Verification

- Run: `nix flake check`
