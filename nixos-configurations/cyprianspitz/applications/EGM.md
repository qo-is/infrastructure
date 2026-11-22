# cyprianspitz applications

## Overview

Service enablement for the cyprianspitz host: loadbalancer, backup server, authoritative DNS and VPN server.

## Interface

- `qois.loadbalancer.enable = true`; `qois.backplane-net.hosts.loadbalancers = mkForce [ "cyprianspitz" ]` [default.nix].
- `qois.backup-server` with `backupStorageRoot` derived from the `/backup` subvolume of `lv_data` in disko [backup.nix:qois.backup-server].
- `qois.knot` listening on `<plessur-lan ip>@53` [dns.nix:qois.knot.listenAddresses].
- `qois.nginx.behindLoadbalancer = true`, `qois.vpn-server.enable = true` [vpn.nix].

## Invariants

- `backupStorageRoot` depends on `disko.devices.lvm_vg.vg_data.lvs.lv_data` and its `/backup` subvolume existing [backup.nix:dataVolume].
- Loadbalancer list is forced to cyprianspitz only [default.nix:qois.backplane-net.hosts.loadbalancers].

## Side Effects

- Serves DNS on port 53 of the LAN IP, hosts VPN server and receives backups [dns.nix, vpn.nix, backup.nix].

## Verification

- Build: `nix build .#nixosConfigurations.cyprianspitz.config.system.build.toplevel`
- All: `nix flake check`
