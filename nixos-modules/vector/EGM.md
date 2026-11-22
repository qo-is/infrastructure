# vector

## Overview

Vector agent shipping the systemd journal to [Loki](../loki/EGM.md). Tested by `test.nix` / `test.py`.

## Interface

- `qois.vector.enable` (bool) [default.nix:options.qois.vector.enable]
- `qois.vector.lokiEndpoint` (str, default `http://lindberg-webapps.backplane.net.qo.is:<qois.loki.port>`) [default.nix:options.qois.vector.lokiEndpoint]

## Invariants

- Source is `journald`; the `unit` label is `_SYSTEMD_UNIT` or `"none"` [default.nix:transforms.with_unit_label]
- Loki labels are `host` (networking.hostName) and `unit`; encoding is `text` [default.nix:sinks.loki]

## Side Effects

- Enables `services.vector` with `journaldAccess` [default.nix:services.vector]
- Pushes logs to the Loki endpoint over the network [default.nix:sinks.loki]

## Verification

- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-vector`
- Run: `nix flake check`
