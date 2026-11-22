# vpn-server

## Overview

Headscale (Tailscale-compatible) control server behind nginx. Client and key management in the legacy [README](./README.md). Exit nodes use [vpn-exit-node](../vpn-exit-node/EGM.md).

## Interface

- `qois.vpn-server.enable` (bool) [default.nix:options.qois.vpn-server.enable]
- `qois.vpn-server.domain` (str, default `vpn.qo.is`) [default.nix:options.qois.vpn-server.domain]
- `qois.vpn-server.dnsRecords` (attrsOf str, default all `qois.loadbalancer.domains` to the lindberg backplane IP, `vpn.qo.is` to the cyprianspitz backplane IP) [default.nix:defaultDnsRecords]
- `qois.vpn-server.wheelUsers` (listOf str, default `[ ]`) [default.nix:options.qois.vpn-server.wheelUsers]

## Invariants

- Headscale listens on `127.0.0.1:46084`; nginx proxies the domain to it (with websockets) on ports 8443 (SSL) and 8080 (HTTP) [default.nix:services.headscale] [default.nix:services.nginx]
- Starts after `wireguard-wg-backplane.service` [default.nix:systemd.services.headscale.after]
- ACL policy: `tag:srv`/`srv@` may talk to everything; everyone may reach srv hosts; `group:wheel` (from `wheelUsers`) may reach everything; exit nodes auto-approved for `tag:srv` and wheel; backplane route auto-approved for `tag:srv` [default.nix:aclPolicy]
- MagicDNS on, base domain from the virtual `vpn` network, backplane domain as search domain [default.nix:dns]
- Reverse path check is `loose` [default.nix:networking.firewall.checkReversePath]

## Side Effects

- Opens TCP for headscale, nginx SSL and HTTP ports and UDP 41641 [default.nix:networking.firewall]
- Adds headscale sqlite DB, noise key and DERP paths to `qois.backup-client.includePaths` [default.nix:qois.backup-client.includePaths]
- Installs `headscale` CLI; maps domain to 127.0.0.1; enables ACME and `forceSSL` on the nginx host [default.nix]

## Verification

- Run: `nix flake check`
