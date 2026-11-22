# lindberg applications

## Overview

Service enablement for lindberg: loadbalancer and an SSH jump user.

## Interface

- `./loadbalancer.nix`, `./ssh-forwarding.nix` imported [default.nix:imports].
- `qois.loadbalancer.enable = true` [loadbalancer.nix].
- User and group `tunnel` (system user, `nologin` shell, no home, one ed25519 authorized key) [ssh-forwarding.nix:users.users.tunnel, users.groups.tunnel].

## Invariants

- `tunnel` has no login shell and is meant only for jumphost forwarding [ssh-forwarding.nix:shell].

## Side Effects

- Grants SSH access for the listed key to lindberg as `tunnel` [ssh-forwarding.nix:openssh.authorizedKeys.keys].

## Verification

- Build: `nix build .#nixosConfigurations.lindberg.config.system.build.toplevel`
- All: `nix flake check`
