# auto-deploy

## Overview

Shell application that runs `deploy` (deploy-rs) with retries for every flake deploy node that has a given profile.

## Interface

- Derivation `auto-deploy` via `writeShellApplication`, description "Deploy machines automatically." [default.nix:writeShellApplication]
- CLI: `auto-deploy <profile>` where the profile is e.g. `system-vm` [script.bash:PROFILE]
- Env var `SSH_DEPLOY_KEY`: optional private key content, written to a temp file and passed as `-i` [script.bash:SSH_DEPLOY_KEY]
- Runtime deps: `deploy-rs`, `gitMinimal` [default.nix:runtimeInputs]

## Invariants

- Exits 1 without a profile argument [script.bash:PROFILE]
- Exits 1 if no node in `deploy.nodes` has the profile [script.bash:HOSTS]
- Each host is deployed with up to 3 attempts and a growing sleep between attempts [script.bash:retry]
- Always uses `--skip-checks` and a known-hosts file built from `nixosConfigurations.lindberg` [script.bash:KNOWN_HOSTS_FILE]

## Side Effects

- Writes the SSH key to `/dev/shm/ssh_deploy_key.*` (mode 600), removed by traps on EXIT/SIGINT/SIGTERM/SIGQUIT [script.bash:TEMP_KEY_FILE]
- Runs `nix eval` and the known-hosts `nix build` against the flake root, so it works from any directory inside the repo [script.bash:HOSTS] [script.bash:KNOWN_HOSTS_FILE]
- Deploys over SSH to hosts [script.bash:deploy]

## Verification

- Run: `nix build .#auto-deploy`
