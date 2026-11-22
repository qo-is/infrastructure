# sops-config

## Overview

Generates the `.sops.yaml` content (as JSON) with creation rules derived from host metadata and the user PGP keys in the private submodule.

## Interface

- Derivation `.sops.yaml` via `writeText` [default.nix:writeText]
- Inputs: `private` (submodule, `sops_keys/*.asc`), `defaults/meta/hosts.nix` [default.nix:userPgpKeys, metaHostConfigs]
- Creation rules \[default.nix:creation_rules\]:
  - `private/passwords.sops.*` for user PGP keys
  - `private/nixos-modules/shared-secrets/default.sops.*` for user PGP keys and all server age keys
  - `private/nixos-modules/kanidm/<server>.sops.*` for the server key plus the key of `kanidmHost` (`lindberg-webapps`), plus the user PGP keys
  - `private/nixos-configurations/<server>/secrets.sops.*` for that server's key plus the user PGP keys

## Invariants

- Server age keys come from hosts that have an `sshKey`, converted with `ssh-to-age` [default.nix:serverAgeKeys]
- `userAgeKeys` is empty [default.nix:userAgeKeys]

## Side Effects

- Reads fingerprints of user keys using `gpg` in a build sandbox [default.nix:gpgFingerprintsFile]

## Verification

- Run: `nix build .#sops-config`
