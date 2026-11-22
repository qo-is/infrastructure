# Topology

## Overview

Renders network diagrams (hosts/services and networks) with nix-topology from the NixOS configurations plus hand-declared external devices. Network data comes from `qois.meta` (see [defaults/meta](../defaults/meta/EGM.md)). Output is embedded in the docs ([network.md](../defaults/meta/network.md)).

## Interface

- `${system}`: result of `import nix-topology` with the `nix-topology` overlay (for `elk-to-svg`), modules `./networks.nix`, `./nodes.nix`, and `{ inherit (self) nixosConfigurations; }` [default.nix:default].
- `specialArgs.qoisMeta`: `self.nixosConfigurations.calanda.config.qois.meta` [default.nix:specialArgs].
- `networks`: one entry per `qoisMeta.network.physical` (solid style, suffix empty) and `network.virtual` (dashed, suffix ` (virtual)`); name is `<domain><suffix>`, `cidrv4` is `<id>/<prefixLength>` or `null`; colors cycle through fixed palettes [networks.nix:mkNetworks, networks.nix:mkCidrV4, networks.nix:tryNetworkId].
- `nodes`: `internet`, `media-converter-chur`, `riedbach-router` (external, hand declared); interface/network overrides for `calanda`, `cyprianspitz`, `lindberg`; libvirt guests `lindberg-nextcloud`, `lindberg-build`, `lindberg-webapps` via `mkVirtualMachine` [nodes.nix:nodes, nodes.nix:mkVirtualMachine].

## Invariants

- `riedbach-ext` has no `v4.id` (ISP-assigned); `tryNetworkId` uses `builtins.tryEval` so its `cidrv4` is `null` [networks.nix:tryNetworkId].
- calanda's `enp4s0` address is forced to `physical.plessur-ext.hosts.calanda.v4.ip` [nodes.nix:calanda.interfaces].
- `qois.meta` is identical on all hosts, so reading it from calanda is sufficient [default.nix:specialArgs].
- VM parent is always `lindberg`, `guestType = "libvirt"` [nodes.nix:mkVirtualMachine].

## Side Effects

None. Pure evaluation; the diagrams are only produced when the output is built.

## Verification

- Run: `nix build .#topology.x86_64-linux.config.output`
- Run: `nix flake check`
