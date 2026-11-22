# router

## Overview

SOHO router role: NAT, bridge and basic firewalling. Sibling modules [router-dhcp](../router-dhcp/EGM.md), [router-dns](../router-dns/EGM.md) and [router-wireless-ap](../router-wireless-ap/EGM.md) extend it under `qois.router.*`. Legacy overview in [README](./README.md).

## Interface

- `qois.router.enable` (bool) [default.nix:options.qois.router.enable]
- `qois.router.wanInterface` (nullOr str, default null) [default.nix:options.qois.router.wanInterface]
- `qois.router.wirelessInterfaces` (listOf str, default `[ ]`) [default.nix:options.qois.router.wirelessInterfaces]
- `qois.router.lanInterfaces` (listOf str, default `[ ]`) [default.nix:options.qois.router.lanInterfaces]
- `qois.router.internalRouterIP` (str, required) [default.nix:options.qois.router.internalRouterIP]
- `qois.router.internalPrefixLength` (int 0..32, default 24) [default.nix:options.qois.router.internalPrefixLength]
- `qois.router.internalBridgeInterfaceName` (str, default `"lan"`) [default.nix:options.qois.router.internalBridgeInterfaceName]

## Invariants

- NAT is configured only if `wanInterface` is non-null [default.nix:networking.nat]
- IPv6 is disabled on the host (TODO in code) [default.nix:networking.enableIPv6]
- The bridge interface is a trusted firewall interface [default.nix:networking.firewall.trustedInterfaces]
- Wireless interfaces are not added to the bridge here; hostapd adds them [default.nix:networking.bridges]

## Side Effects

- Creates a bridge with `lanInterfaces` and assigns `internalRouterIP/internalPrefixLength` [default.nix:networking.bridges] [default.nix:networking.interfaces]
- Sets the nix-topology device icon `devices.router` [default.nix:topology.self.deviceIcon]

## Verification

- Run: `nix flake check`
