# ADR 0001: Atlas Network

- Status: Proposed
- Date: 2026-11-01

## Context

Routed container IPs (see [ADR 0002](0002-nixos-containers.md)) must cross host boundaries.
WireGuard only forwards a destination that is in a peer's `AllowedIPs`, and the `backplane`
only routes each peer's own address.

## Decision

- A second WireGuard network, `atlas` (`10.249.0.0/24`, `atlas.net.qo.is`), connects the
  physical hosts `calanda`, `cyprianspitz` and `lindberg`.
  It is configured statically by the `qois.atlas-net` module on the interface `wg-atlas`.
  Peers, endpoints, listen ports and `AllowedIPs` are derived from `qois.meta`.
- Roles:
  - `lindberg` and `cyprianspitz` run the loadbalancers and host containers.
  - `calanda` is a peer, so it can take either role later.
- A peer's `AllowedIPs` are exactly its atlas IP plus the `/32` of every container whose `host`
  is that peer.
  Moving a container is a change in meta and a deployment of every peer.
- Endpoints:
  - `calanda` reaches `cyprianspitz` over `plessur-lan`.
  - `lindberg` reaches `cyprianspitz` via a UDP port forward on `calanda` (with `loopbackIPs`).
  - `lindberg` has no inbound endpoint and keeps its tunnels up with `persistentKeepalive`.
- Private keys are generated on the host (as for the `backplane`), public keys live in meta.
- IPv4 only.

## Consequences

- The `backplane` stays untouched and keeps carrying management traffic between all hosts.
- Plain L3 routing without NAT or encapsulation between hosts.
- Peers without a reachable endpoint (`lindberg`) depend on the others being reachable.
- New hosts need a meta entry and a deployment of every peer.
