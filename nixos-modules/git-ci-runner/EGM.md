# git-ci-runner

## Overview

Forgejo Actions runners on podman: a default Docker/Ubuntu runner and N hardened `nix` runners that execute jobs in a minimal `gitea-runner-nix` image sharing the host `/nix`. Runner for [git](../git/EGM.md). See [legacy README](./README.md).

## Interface

- `qois.git-ci-runner.enable` (bool, default false) [default.nix:enable]
- `qois.git-ci-runner.domain` (str, default `git.qo.is`) [default.nix:domain]
- `qois.git-ci-runner.nixInstances` (`numbers.positive`, default 2) [default.nix:nixInstances]
- `qois.git-ci-runner.trustedSubstituters` (listOf str; cache.nixos.org, nixpkgs-cache host, cache.garnix.io, two attic.qo.is caches) [default.nix:trustedSubstituters]
- `qois.git-ci-runner.trustedPublicKeys` (listOf str; matching keys) [default.nix:trustedPublicKeys]
- Runner labels: `ubuntu-latest`, `ubuntu-22.04`, `docker` (instance `default`), `nix` (instances `nix0..nixN-1`) [default.nix:labels]

## Invariants

- Instance names: `default` and `nix<n>`; services `gitea-runner-<instance>.service` [default.nix:defaultInstanceName, genList]
- Default runner capacity 30, fetch interval `20s`, container network `host` [default.nix:settings.runner]
- Nix runners run containers as `nixuser`, mounting `/nix`, `/dev/kvm` and a `storeDeps` bin/etc-ssl closure; only these volumes are valid [default.nix:container.options, container.valid_volumes]
- Nix runner units are hardened (`DynamicUser`, `NoNewPrivileges`, `ProtectSystem=strict`, restricted syscalls and address families) and require `gitea-runner-nix-image.service` [default.nix:systemd.services nix runners]
- Podman storage driver is `btrfs` at `/var/lib/containers/storage` [default.nix:virtualisation.containers.storage.settings]
- `MemoryDenyWriteExecute = false`, `LockPersonality = false`, `ProcSubset = "all"` by design (Node, nix) [default.nix:serviceConfig]

## Side Effects

- sops secret `forgejo/runner-registration-token` (restarts runner units) [default.nix:sops.secrets]
- Sets `nix.settings.trusted-substituters` and `trusted-public-keys` [default.nix:nix.settings]
- Enables podman with docker compat/socket and autoPrune [default.nix:virtualisation.podman]
- Creates oneshot `gitea-runner-nix-image.service` that imports the `gitea-runner-nix` image into podman [default.nix:systemd.services.gitea-runner-nix-image]
- Creates user/group `nixuser` [default.nix:users.users.nixuser, users.groups.nixuser]
- Registers runners with `https://<domain>` using forgejo-runner [default.nix:services.gitea-actions-runner]

## Verification

- Run: `nix flake check`
