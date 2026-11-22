# vpn-exit-node

## Overview

Tailscale client acting as exit node and backplane subnet router for the Headscale server of [vpn-server](../vpn-server/EGM.md).

## Interface

- `qois.vpn-exit-node.enable` (bool) [default.nix:options.qois.vpn-exit-node.enable]
- `qois.vpn-exit-node.domain` (str, default `vpn.qo.is`; login server) [default.nix:options.qois.vpn-exit-node.domain]

## Invariants

- Advertises exit node, the backplane v4 prefix, and tag `tag:srv`; DNS and routes are not accepted [default.nix:extraUpFlags]
- Authenticates with `tailscale/key` as auth key file [default.nix:services.tailscale.authKeyFile]

## Side Effects

- Enables `services.tailscale` with `openFirewall` and `useRoutingFeatures = "server"`, logging disabled (`--no-logs-no-support`) [default.nix:services.tailscale]
- Declares sops secret `tailscale/key` restarting `tailscaled.service` [default.nix:sops.secrets."tailscale/key"]
- Adds `/var/lib/tailscale` to `qois.backup-client.includePaths` [default.nix:qois.backup-client.includePaths]
- Registers a virtual `tailscale0` interface on network `vpn` in nix-topology [default.nix:topology.self.interfaces.tailscale0]

## Verification

- Run: `nix flake check`
