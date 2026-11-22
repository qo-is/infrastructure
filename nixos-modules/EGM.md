# nixos-modules

## Overview

Reusable NixOS modules, all under the `qois.*` option namespace. `default.nix` exposes a single `nixosModules.default` that imports every subdirectory containing a `default.nix` plus the shared external modules. Hosts in [nixos-configurations](../nixos-configurations/EGM.md) enable the modules per service.

## Interface

- `nixosModules.default` [default.nix:default]
- Imports `self.lib.loadSubmodulesFrom ./.` (see [lib](../lib/EGM.md)) [default.nix:imports]
- Imports `../defaults/meta` (see [defaults/meta](../defaults/meta/EGM.md)), `disko.nixosModules.disko`, `nix-topology.nixosModules.default`, `sops-nix.nixosModules.sops`, `private.nixosModules.default` [default.nix:imports]

### Base system

- [system](./system/EGM.md): baseline host config (srvos server, nix, hardening) with `qois.system.physical` and `qois.system.virtual-machine` variants
- [meta](./meta/EGM.md): typed `qois.meta.hosts` / `qois.meta.network.*` options and derived SSH known hosts
- [networkd](./networkd/EGM.md): systemd-networkd and resolved toggle
- [nginx](./nginx/EGM.md): shared nginx defaults and PROXY protocol trust (`qois.nginx.behindLoadbalancer`)
- [postgresql](./postgresql/EGM.md): shared PostgreSQL defaults, backups, telegraf grants, opt-in `pg_upgrade`
- [security-overrides](./security-overrides/EGM.md): pins nginx and Nextcloud PHP to fixed nixpkgs commits
- [outgoing-server-mail](./outgoing-server-mail/EGM.md): msmtp outbound mail via mail.cyon.ch
- [initrd-ssh-unlock](./initrd-ssh-unlock/EGM.md): LUKS unlock via SSH in systemd initrd
- [luks-ssh](./luks-ssh/EGM.md): LUKS unlock via `boot.initrd.network` SSH server

### Networking, VPN and routing

- [backplane-net](./backplane-net/EGM.md): WireGuard full-mesh overlay driven by wgautomesh
- [backplane-net.hosts](./backplane-net.hosts/EGM.md): hosts entries mapping loadbalanced domains to loadbalancer backplane IPs
- [loadbalancer](./loadbalancer/EGM.md): HAProxy SNI/Host loadbalancer to backplane hosts
- [knot](./knot/EGM.md): authoritative Knot DNS with DNSSEC
- [vpn-server](./vpn-server/EGM.md): Headscale control server
- [vpn-exit-node](./vpn-exit-node/EGM.md): Tailscale exit node and backplane subnet router
- [router](./router/EGM.md), [router-dhcp](./router-dhcp/EGM.md), [router-dns](./router-dns/EGM.md), [router-wireless-ap](./router-wireless-ap/EGM.md): SOHO router role (NAT/bridge, dnsmasq, unbound, hostapd)
- [wwan](./wwan/EGM.md): MBIM WWAN client

### Applications

- [cloud](./cloud/EGM.md): Nextcloud
- [git](./git/EGM.md): Forgejo
- [git-ci-runner](./git-ci-runner/EGM.md): Forgejo Actions runners on podman
- [vault](./vault/EGM.md): Vaultwarden
- [static-page](./static-page/EGM.md): static nginx sites with per-domain deploy users
- [attic](./attic/EGM.md): Attic binary cache
- [nixpkgs-cache](./nixpkgs-cache/EGM.md): nginx caching proxy for cache.nixos.org
- [renovate](./renovate/EGM.md): Renovate bot

### Identity

- [kanidm](./kanidm/EGM.md): Kanidm IdP with declarative groups, OAuth2 clients and mail sender
- [kanidm-relying-party](./kanidm-relying-party/EGM.md): shared OAuth2 relying-party abstraction
- [kanidm-forgejo](./kanidm-forgejo/EGM.md), [kanidm-grafana](./kanidm-grafana/EGM.md), [kanidm-prometheus](./kanidm-prometheus/EGM.md): SSO integrations

### Backup

- [backup-client](./backup-client/EGM.md): Borg jobs to backup servers over the backplane
- [backup-server](./backup-server/EGM.md): Borg repositories and snapper snapshots

### Observability

- [telegraf](./telegraf/EGM.md): Telegraf agent, service inputs, periodic job status, central blackbox monitoring
- [prometheus](./prometheus/EGM.md): Prometheus scraping telegraf on backplane hosts
- [alertmanager](./alertmanager/EGM.md): Alertmanager e-mail alerting and qois alert rules
- [grafana](./grafana/EGM.md): Grafana with provisioned datasources
- [loki](./loki/EGM.md): single-node Loki
- [vector](./vector/EGM.md): journald-to-Loki shipper

## Invariants

- A module is loaded only if its directory contains `default.nix` [default.nix:imports] (see `foldersWithNix` in [lib](../lib/EGM.md))
- Each module guards its config with its `qois.<name>.enable` option, except base modules that apply unconditionally (e.g. shared nginx defaults in [nginx](./nginx/EGM.md), `serviceInputs` merging in [telegraf](./telegraf/EGM.md))
- Telegraf SMART, mdstat, ZFS and disk inputs come from `srvos` `mixins-telegraf`, not from this directory

## Side Effects

- None at import; side effects are per module when enabled (see child contracts)

## Verification

- Run all module tests: `nix build .#checks.x86_64-linux.nixos-modules`
- Run one: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-<module>`
- Run: `nix flake check`
