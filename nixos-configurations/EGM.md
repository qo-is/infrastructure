# nixos-configurations

## Overview

One directory per host; `default.nix` builds a `nixosSystem` (x86_64-linux) for every subdirectory containing a `default.nix`. Setup procedure for new hosts: [setup.md](./setup.md).

## Interface

- `default.nix` exports `genAttrs (self.lib.foldersWithNix ./.)` of `nixosSystem` with `specialArgs.inputs` and modules `self.nixosModules.default` plus `./<host>/default.nix` [default.nix].
- Hosts:
  - [calanda](./calanda/EGM.md): APU router/gateway (physical).
  - [cyprianspitz](./cyprianspitz/EGM.md): physical server, DNS, VPN, backups, libvirt.
  - [lindberg](./lindberg/EGM.md): main physical server, libvirt host, loadbalancer.
  - [lindberg-build](./lindberg-build/EGM.md): CI/cache VM (`system-ci`).
  - [lindberg-nextcloud](./lindberg-nextcloud/EGM.md): Nextcloud VM (`system-vm`).
  - [lindberg-webapps](./lindberg-webapps/EGM.md): web apps and monitoring VM (`system-vm`).

## Invariants

- A host is only discovered if its directory contains `default.nix` [default.nix:configs].
- Every host sets `qois.system.physical.enable` or `qois.system.virtual-machine.enable` and `system.stateVersion = "26.05"`.
- Deploy category is derived: `system-ci` for `qois.git-ci-runner.enable`, `system-vm` for qemuGuest hosts without CI runner, otherwise `system-physical` (`deploy/system-*/default.nix`).

## Side Effects

- None at evaluation; host builds and deployments are driven from `checks/` and `deploy/`.

## Verification

- Run: `nix flake check`
- Per host: `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
- Deploy: `deploy --skip-checks .#<host>.<category>`
