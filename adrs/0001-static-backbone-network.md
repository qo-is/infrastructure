# ADR 0001: Static Backbone Network

- Status: Proposed
- Date: 2026-11-01

## Context

Routed service IPs (see [ADR 0002](0002-nixos-containers.md)) must cross host boundaries.
WireGuard only forwards a destination that is in a peer's `AllowedIPs`, and `wgautomesh`, which
manages the `backplane`, resets every peer to its single `/32` on reconfiguration.

## Decision

- A second WireGuard network, `backbone` (`10.249.0.0/24`, `backbone.net.qo.is`), connects the
  physical hosts `calanda`, `cyprianspitz` and `lindberg`.
- It is configured statically with `networking.wireguard`, without `wgautomesh`.
  Peers, endpoints and `AllowedIPs` are derived from `qois.meta`.
- A peer's `AllowedIPs` are its backbone IP plus the routed prefixes it hosts, e.g. the
  `/32` of every container whose `host` is that peer.
  Moving a prefix to another host is a change in meta and a deployment of both hosts.
- Endpoints: `calanda` directly, `cyprianspitz` via a port forward on `calanda`.
  `lindberg` has no inbound endpoint and keeps its tunnels up with `persistentKeepalive`.
- Private keys are generated on the host (as for the `backplane`), public keys live in meta.
- The `backplane` stays unchanged and keeps carrying management traffic between all hosts.

## Consequences

- No patch to `wgautomesh`, and no encapsulation on top of the `backplane`.
- Plain L3 routing without NAT between hosts.
- Peers without a reachable endpoint (`lindberg`) depend on the others being reachable.
- New hosts need a meta entry and a deployment of every peer.
