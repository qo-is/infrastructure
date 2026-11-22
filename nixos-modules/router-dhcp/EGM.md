# router-dhcp

## Overview

Local DHCP and local-domain DNS via dnsmasq on the router bridge. DNS is exposed on a non-standard port; recursive resolution is done by [router-dns](../router-dns/EGM.md). The source is a mostly-commented dnsmasq template.

## Interface

- `qois.router.dhcp.enable` (bool) [default.nix:options.qois.router.dhcp.enable]
- `qois.router.dhcp.localDomain` (str, required) [default.nix:options.qois.router.dhcp.localDomain]
- `qois.router.dhcp.dhcpRange` (str, dnsmasq format `start,end`, required) [default.nix:options.qois.router.dhcp.dhcpRange]
- `qois.router.dhcp.localDnsPort` (int 0..65535, default 5553) [default.nix:options.qois.router.dhcp.localDnsPort]

## Invariants

- dnsmasq listens only on `qois.router.internalBridgeInterfaceName` and `lo`, with `bind-interfaces`; DHCP is disabled on `lo` [default.nix:settings.interface] [default.nix:settings.no-dhcp-interface]
- `domain-needed`, `bogus-priv`, `no-hosts`, `expand-hosts`, `dhcp-authoritative` are set; leases last 48h [default.nix:settings]
- DHCP option 6 hands out `qois.router.internalRouterIP` as DNS server; domain-search is `localDomain` [default.nix:settings.dhcp-option]
- The host name resolves to the router IP under `localDomain` [default.nix:settings.address]
- `services.dnsmasq.resolveLocalQueries = false`; the system nameserver is set by router-dns [default.nix:services.dnsmasq.resolveLocalQueries]
- dnsmasq is bound to `network-addresses-<bridge>.service` [default.nix:systemd.services.dnsmasq.bindsTo]

## Side Effects

- Enables `services.dnsmasq` serving DHCP on the LAN bridge [default.nix:services.dnsmasq]

## Verification

- Run: `nix flake check`
