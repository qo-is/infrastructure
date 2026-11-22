# Meta

## Overview

Static host and network metadata exposed as `qois.meta.*` options values, shared by every host and by [topology](../../topology/EGM.md). Legacy network documentation: [network.md](./network.md) (diagrams, DNS, contacts).

## Interface

- `default.nix`: module importing `hosts.nix`, `network-physical.nix`, `network-virtual.nix` [default.nix:imports].
- `qois.meta.hosts`: parsed from `hosts.json` via `builtins.fromJSON` [hosts.nix:qois.meta.hosts].
- `hosts.json` schema: attrset keyed by host name (`calanda`, `lindberg`, `lindberg-nextcloud`, `lindberg-build`, `lindberg-webapps`, `cyprianspitz`), each with `hostName` (string) and `sshKey` (ed25519 public key string) [hosts.json].
- `qois.meta.network.physical`: `plessur-ext`, `plessur-dmz`, `plessur-lan`, `riedbach-ext`; fields `v4.{id,prefixLength,gateway,nameservers}`, `v6.{id,prefixLength}`, `domain`, `hosts.<name>.v4.ip` [network-physical.nix:qois.meta.network.physical].
- `qois.meta.network.virtual`: `vpn` (100.64.0.0/10), `backplane` (10.250.0.0/24, per-host `v4.ip`, `publicKey` (WireGuard), optional `endpoint.{fqdn,port}`, `persistentKeepalive`), `lindberg-vms-nat` (10.247.0.0/24), `cyprianspitz-vms-nat` (10.248.0.0/24) [network-virtual.nix:qois.meta.network.virtual].

## Invariants

- `riedbach-ext` is dynamic and defines no `v4.id`; consumers must tolerate that [network-physical.nix:riedbach-ext, ../../topology/networks.nix:tryNetworkId].
- Backplane endpoints reference `physical-network.plessur-ext.hosts.calanda.fqdn`, which is derived from host name and network domain by the option defaults in [nixos-modules/meta](../../nixos-modules/meta/EGM.md) [network-virtual.nix:endpoint] [nixos-modules/meta/network.nix:mkFqdn].
- Adding a host requires entries in `hosts.json` and, for backplane membership, `network-virtual.nix` [hosts.nix, network-virtual.nix:backplane.hosts].
- `network.md` includes the [backplane-net](../../nixos-modules/backplane-net/README.md) README via mdbook [network.md].

## Side Effects

None. Pure data; reads `hosts.json` at evaluation time.

## Verification

- Run: `nix flake check`
