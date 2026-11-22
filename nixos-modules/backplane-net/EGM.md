# backplane-net

## Overview

WireGuard full-mesh overlay network (`backplane`) kept connected by `wgautomesh`. Host and peer data come from `qois.meta.network.virtual`. See [legacy README](./README.md).

## Interface

- `qois.backplane-net.enable` (bool, default false) [default.nix:enable]
- `qois.backplane-net.netName` (str, default `backplane`) [default.nix:netName]
- `qois.backplane-net.port` (number, default 51825) [default.nix:port]
- Related module: [backplane-net.hosts](../backplane-net.hosts/EGM.md)

## Invariants

- `netName` must exist in `qois.meta.network.virtual` and the host in its `hosts`; evaluation throws a named error otherwise [default.nix:netConfig, hostNetConfig]
- Interface is named `wg-${netName}`; address is the host's `v4.ip` with the network's prefix length [default.nix:networking.wireguard.interfaces]
- Listen port is the host's `endpoint.port` if it has an endpoint, otherwise `cfg.port`; the same port is opened in UDP firewall [default.nix:listenPort, networking.firewall.allowedUDPPorts]
- Private key lives at `/secrets/wireguard/private/${netName}` and is generated if missing [default.nix:privateKeyFile, generatePrivateKeyFile]
- wgautomesh peers are all other hosts of the network (address, optional `fqdn:port` endpoint, public key) [default.nix:services.wgautomesh.settings.peers]
- `wgautomesh.service` requires and starts after the WireGuard unit and `network-online.target` [default.nix:systemd.services.wgautomesh]
- Uses scripted (non-networkd) wireguard backend [default.nix:networking.wireguard.useNetworkd]

## Side Effects

- sops secret `wgautomesh/gossip-secret` (restarts `wgautomesh.service`) [default.nix:sops.secrets]
- Enables `services.wgautomesh` with `openFirewall = true`, log level `warn` [default.nix:services.wgautomesh]
- Excludes the interface from `systemd.network.wait-online` [default.nix:systemd.network.wait-online.ignoredInterfaces]
- Declares the interface in nix-topology (`topology.self.interfaces`) [default.nix:topology.self.interfaces]

## Verification

- Run: `nix flake check`
