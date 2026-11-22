# static-page

## Overview

Static nginx sites whose content is a deployable nix profile per domain. Legacy notes in [README](./README.md). Tested by `test.nix` / `test.py`.

## Interface

- `qois.static-page.enable` (bool) [default.nix:options.qois.static-page.enable]
- `qois.static-page.pages` (attrsOf submodule) with `domain` (str, default attribute name), `domainAliases` (listOf str, default `[ ]`), `authorizedKeys` (listOf str, default `[ ]`) [default.nix:pageType]
- Default pages (`mkDefault`): `fabianhauser.ch` (with aliases), `docs-ops.qo.is`, `qo.is` (alias `www.qo.is`), each with a CI deploy key [default-pages.nix:qois.static-page.pages]

## Invariants

- Each page gets a system user and group `<nginx user>-<domain>` with home `/var/lib/<user>` (mode 750) and webroot `<home>/.local/state/nix/profiles/webroot` [default.nix:pageConfigs]
- The nginx user is added to every page group [default.nix:users.users]
- The first alias gets a virtual host with `globalRedirect` to the primary domain and `serverAliases` for the rest [default.nix:mkAliasVhost]
- Virtual hosts use `enableACME` and `forceSSL` [default.nix:defaultVhostConfig]
- Changing `domain` changes the user, root and home (see option description) [default.nix:domain]

## Side Effects

- Creates users, groups and SSH authorized keys for deployment [default.nix:users]
- Maps all domains and aliases to 127.0.0.1 in `networking.hosts` [default.nix:networking.hosts]
- Adds a telegraf `x509_cert` service input for all domains [default.nix:qois.telegraf.serviceInputs.x509_cert]
- Enables `services.nginx` with the virtual hosts [default.nix:services.nginx]
- Domains feed the [loadbalancer](../loadbalancer/EGM.md) defaults (`qois.static-page.pages` is read there)

## Verification

- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-static-page`
- Run: `nix flake check`
