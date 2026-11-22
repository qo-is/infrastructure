# wwan

## Overview

MBIM WWAN client: brings up a modem connection with libmbim and applies the IP configuration to the interface. Limitations (IPv4 tested only, polling) in the legacy [README](./README.md). Unlinked asset: `mbim-ip.bash`.

## Interface

- `qois.wwan.enable` (bool) [default.nix:options.qois.wwan.enable]
- `qois.wwan.apn` (str, required) [default.nix:options.qois.wwan.apn]
- `qois.wwan.apnUser`, `apnPass` (str, default `""`) [default.nix:options.qois.wwan.apnUser]
- `qois.wwan.apnAuth` (enum `PAP`/`CHAP`/`MSCHAPV2`/`""`, default `""`) [default.nix:options.qois.wwan.apnAuth]
- `qois.wwan.mbimProxy` (bool, default true) [default.nix:options.qois.wwan.mbimProxy]
- `qois.wwan.mbimInterface` (str, default `/dev/cdc-wdm0`) [default.nix:options.qois.wwan.mbimInterface]
- `qois.wwan.networkInterface` (str, required) [default.nix:options.qois.wwan.networkInterface]
- Scripts `mbim-ip-configured start|stop <iface>` [mbim-ip.bash:interface_start] and `mbim-check-status` [default.nix:mbim-check-status]

## Invariants

- `wwan.service` is bound to `network-addresses-<networkInterface>.service` and stays active after exit [default.nix:systemd.services.wwan]
- `mbim-check-status` does nothing if `wwan.service` is inactive; it restarts it when the status is not `activated` [default.nix:mbim-check-status]
- The check timer fires 2m after boot and every 1m after [default.nix:systemd.timers."wwan-check"]
- The script does not configure nameservers (prints a note) [mbim-ip.bash]
- APN credentials are written in plain text into the nix store via `/etc/mbim-network.conf` [default.nix:environment.etc."mbim-network.conf"]

## Side Effects

- Defines systemd services `wwan`, `wwan-check` and timer `wwan-check` [default.nix:systemd]
- Flushes and sets addresses and routes on the interface via `ip` [mbim-ip.bash:interface_stop]
- Disables DHCP on `networkInterface` [default.nix:networking.interfaces]
- Writes `/etc/mbim-network.conf` [default.nix:environment.etc."mbim-network.conf"]

## Verification

- Run: `nix flake check`
