# deploy/docs-ops

## Overview

deploy-rs profile that publishes the docs site to the web root of `docs-ops.qo.is`.

## Interface

- Node `lindberg-webapps`, profile `docs-ops.qo.is` [default.nix:nodes.lindberg-webapps.profiles]
- `sshUser` is `nginx-docs-ops.qo.is`; `profilePath` is `/var/lib/<sshUser>/.local/state/nix/profiles/webroot` [default.nix:sshUser, profilePath]
- Payload: `self.packages.${system}.docs` activated with `activate.noop` [default.nix:path]

## Invariants

- `remoteBuild = true` because the user is an unprivileged nix user [default.nix:remoteBuild]

## Side Effects

- Replaces the webroot profile of the target on deploy [default.nix:profilePath]

## Verification

- Run: `nix flake check` (deploy-rs checks)
