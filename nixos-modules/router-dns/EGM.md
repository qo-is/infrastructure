# router-dns

## Overview

Recursive, DNSSEC-validating resolver (unbound) for the router LAN. Forwards the local domain and its reverse zone to the dnsmasq instance of [router-dhcp](../router-dhcp/EGM.md).

## Interface

- `qois.router.recursiveDns.enable` (bool) [default.nix:options.qois.router.recursiveDns.enable]
- `qois.router.recursiveDns.networkIdIp` (str, required, e.g. `192.168.0.0`) [default.nix:options.qois.router.recursiveDns.networkIdIp]

## Invariants

- Unbound listens on `127.0.0.1` and `qois.router.internalRouterIP`; access is allowed from `127.0.0.0/24` and `<networkIdIp>/<internalPrefixLength>` [default.nix:settings.server]
- The reverse zone name is derived from the first three octets of `networkIdIp` (assumes a /24 style split) [default.nix:revIpDomain]
- Forward zones `<localDomain>.` and the reverse zone point to `127.0.0.1@<dhcp.localDnsPort>` and are marked insecure/private [default.nix:forward-zone] [default.nix:settings.server]
- Unbound `LimitNOFILE` is 8192 [default.nix:systemd.services.unbound]

## Side Effects

- Sets `networking.nameservers = [ "127.0.0.1" ]` and disables `systemd-resolved` [default.nix:networking.nameservers] [default.nix:systemd.services.systemd-resolved.enable]
- Enables `services.unbound` [default.nix:services.unbound]

## Verification

- Run: `nix flake check`
