# kanidm-grafana

## Overview

Grafana single sign-on through kanidm: declares the `grafana` relying party and configures Grafana's generic OAuth. Uses [kanidm-relying-party](../kanidm-relying-party/EGM.md) and [grafana](../grafana/EGM.md).

## Interface

- `qois.kanidm-grafana.enable` (bool, default false) [default.nix:enable]
- Declares `qois.kanidm-relying-party.grafana` with redirect `https://<grafana.domain>/login/generic_oauth` and role `sysadmin` mapped to `GrafanaAdmin` [default.nix:qois.kanidm-relying-party.grafana]
- Sets `services.grafana.settings."auth.generic_oauth"` when grafana is also enabled [grafana.nix]

## Invariants

- Role precedence is `GrafanaAdmin`, `Admin`, `Editor`, then fallback `Viewer`; only roles present in the party's roles are tested [grafana.nix:rolePrecedence, roleAttributePath]
- PKCE enabled; login attribute `preferred_username`; client secret read via `$__file{}` [grafana.nix:use_pkce, login_attribute_path, client_secret]
- `role_attribute_strict = false` keeps the local admin as fallback; `allow_assign_grafana_admin = true` [grafana.nix]

## Side Effects

- Restarts `grafana.service` on secret change via the relying party consumer (`unit = "grafana"`) [default.nix:consumer]
- Points Grafana at `https://<kanidm.domain>/ui/oauth2`, `/oauth2/token`, and `/oauth2/openid/<clientId>/userinfo` [grafana.nix]

## Verification

- Run: `nix flake check`
- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-kanidm-grafana` (test in `./test.nix`, `./test.py`)
