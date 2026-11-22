# renovate

## Overview

Renovate bot run as a timer against a Gitea/Forgejo server.

## Interface

- `qois.renovate.enable` (bool) [default.nix:options.qois.renovate.enable]
- `qois.renovate.gitServer` (str, default `git.qo.is`) [default.nix:options.qois.renovate.gitServer]
- `qois.renovate.gitAuthor` (str, default `Renovate Bot <sysadmin+renovate@qo.is>`) [default.nix:options.qois.renovate.gitAuthor]

## Invariants

- Platform `gitea`, endpoint `https://<gitServer>/api/v1`, autodiscover on, schedule `*:0/10`, log level warn [default.nix:services.renovate]
- A `~/.netrc` for the git server is written before the service script from the `SECRET-RENOVATE_TOKEN` credential [default.nix:systemd.services.renovate.script]
- The latest nix version is prepended to the service `path` as a workaround (remove once nix >= 2.26 is default) [default.nix:systemd.services.renovate.path]

## Side Effects

- Sops secrets `renovate/token` and `renovate/host_rules` restart `renovate.service` on change [default.nix:sops.secrets]
- Enables `services.renovate` with `RENOVATE_TOKEN` and `RENOVATE_HOST_RULES` credentials [default.nix:services.renovate.credentials]
- Network calls to the configured git server

## Verification

- Run: `nix flake check`
