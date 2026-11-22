# kanidm-relying-party

## Overview

Shared abstraction for OAuth2 relying parties of kanidm. An entry is declared on both the host running kanidm and the host running the relying party; each side sets up its part and both decrypt the client secret from `qois.kanidm.secretsFile`. Used by [kanidm-forgejo](../kanidm-forgejo/EGM.md), [kanidm-grafana](../kanidm-grafana/EGM.md) and [kanidm-prometheus](../kanidm-prometheus/EGM.md); feeds [kanidm](../kanidm/EGM.md).

## Interface

- `qois.kanidm-relying-party.<name>` (attrsOf submodule) with options: `enable`, `clientId` (default name), `secretKey` (internal, readOnly, `kanidm/oauth2/<clientId>`), `displayName`, `originUrl`, `originLanding`, `scopes` (default openid/email/profile), `roles` (attrsOf (listOf str)), `consumer.{enable,unit,user,group}`, `secretFiles.{kanidm,consumer}` (paths, default to the sops secret paths) [default.nix:options.qois.kanidm-relying-party]

## Invariants

- Kanidm side (when `qois.kanidm.enable`): sops secret `<secretKey>/kanidm` owned by the kanidm service user, restarting `kanidm.service` [default.nix:kanidmSecret]
- Consumer side (when `consumer.enable`): sops secret `<secretKey>/<name>` owned by `consumer.user:group`, restarting `<consumer.unit>.service` [default.nix:consumerSecret]
- Both secrets use `sopsFile = qois.kanidm.secretsFile` and key `secretKey` [default.nix:kanidmSecret, consumerSecret]
- Enabled parties on the kanidm host become `qois.kanidm.oauth2Clients.<clientId>` [default.nix:kanidmClient]

## Side Effects

- Declares sops secrets and `qois.kanidm.oauth2Clients` entries as above [default.nix:config]

## Verification

- Run: `nix flake check`
- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-kanidm-relying-party` (test in `./test.nix`, `./test.py`; shared setup in `./test-fixture.nix`)
