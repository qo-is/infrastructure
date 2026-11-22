# meta

## Overview

Typed host and network metadata (`qois.meta.*`) consumed by other modules and configurations (DNS records, wireguard, loadbalancer, SSH known hosts). Values are supplied from `defaults/meta`.

## Interface

- `qois.meta.hosts` (attrsOf submodule) with `hostName` (strMatching hostname regex, default attribute name) and `sshKey` (nullOr ed25519 public key, default null) [hosts.nix:options.qois.meta.hosts]
- `qois.meta.network.physical` (attrsOf submodule, default `{ }`) with `v4` (id, prefixLength, gateway, nameservers), `v6` (nullOr, required without default), `domain`, `hosts.<name>.{v4.ip,v6.ip,fqdn}` [network.nix:options.qois.meta.network.physical]
- `qois.meta.network.virtual` (attrsOf submodule, default `{ }`) with the same fields (but `v6` defaults to null) plus per host `publicKey`, `persistentKeepalive` and optional `endpoint.{fqdn,port}` for VPN servers [network.nix:options.qois.meta.network.virtual]
- `default.nix` imports `hosts.nix` and `network.nix` [default.nix:imports]

## Invariants

- `prefixLength` is 0..32 for v4 and 0..128 for v6 [network.nix:mkNetworkIdOpts]
- Host `fqdn` defaults to `<hostName>.<network domain>` [network.nix:mkFqdn]
- Endpoint `port` is 1..65535 [network.nix:endpoint]

## Side Effects

- Sets `programs.ssh.knownHosts` for every host with an `sshKey`: public key from `hosts.nix`, extra host names (`<host>.<network domain>`, v4 and v6 IPs across all networks) from `network.nix` [hosts.nix:config] [network.nix:config]

## Verification

- Run: `nix flake check`
