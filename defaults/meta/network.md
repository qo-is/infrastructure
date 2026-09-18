# Network

This document provides an overview over the qo.is network structure.

## Diagrams

Both diagrams are generated from the nixos configurations with
[nix-topology](https://github.com/oddlama/nix-topology) and therefore cannot go stale.
Only the parts that are not managed by this repository (the uplinks, the passive media
converter in Chur and the router in Riedbach) are declared by hand in
[topology/nodes.nix](../../topology/nodes.nix).

### Physical View

![Hosts, interfaces and services](main.svg)

### Network View

![Networks and their members](network.svg)

## DNS

All Services are published under the *qo.is* domain name. Following services are available:

`qo.is` Primery Domain - Redirect to docs.qo.is and some .well-known ressources

{{#include ../backplane-net/README.md}}

## Contacts

### Init7

- [Status Netzwerkdienste](https://www.init7.net/status/)
- [NOC E-Mail](mailto:noc@init7.net)
- +41 44 315 44 00
- Init7 (Schweiz) AG, Technoparkstrasse 5, CH-8406 Winterthur
