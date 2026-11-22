# grafana-mcp

## Overview

Wrapper around `mcp-grafana` that reads a Grafana service account token from the user keyring.

## Interface

- Derivation `grafana-mcp`, description "Run mcp-grafana with a service account token from the user keyring" [default.nix:writeShellApplication]
- CLI: `grafana-mcp login` stores a token; any other arguments are passed on to `mcp-grafana` [script.bash:login, exec]
- Env: exports `GRAFANA_URL=https://monitoring.qo.is` and `GRAFANA_SERVICE_ACCOUNT_TOKEN` [script.bash:GRAFANA_URL]
- Runtime deps: `curl`, `libsecret`, `mcp-grafana` [default.nix:runtimeInputs]

## Invariants

- `login` validates the token against `/api/search?limit=1` before storing it [script.bash:curl]
- Exits 1 if no token is in the keyring [script.bash:secret-tool lookup]
- Keyring attributes are `service mcp-grafana url <GRAFANA_URL>` [script.bash:KEYRING_ATTRIBUTES]

## Side Effects

- Network call to the Grafana instance on login [script.bash:curl]
- Writes the token to the user keyring with `secret-tool store` [script.bash:secret-tool store]
- Replaces itself with `mcp-grafana` via `exec` [script.bash:exec]

## Verification

- Run: `nix build .#grafana-mcp`
