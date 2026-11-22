# lindberg-webapps

## Overview

Web applications VM on lindberg (`system-vm` category): vault, git, kanidm, static pages and monitoring.

## Interface

- Imports: [default.nix:imports] `./applications`, `./disko-config.nix`, `./networking.nix`, `./secrets.nix`.
- `qois.system.virtual-machine.enable`, `system.stateVersion = "26.05"` [default.nix].
- Hostname from `meta.hosts.lindberg-webapps.hostName`, DHCP on `enp1s0`, `qois.backplane-net.enable`, tcp 80/443 open [networking.nix].
- Disk via disko: `/dev/vda` GPT with BIOS boot and btrfs (`/nix` zstd, `/` root) [disko-config.nix].
- sops secrets: none declared [secrets.nix:sops.secrets].
- Children: [applications](./applications/EGM.md).

## Invariants

- `/dev/vda` and `enp1s0` must match the VM definition [disko-config.nix; networking.nix].

## Side Effects

- None beyond services enabled in applications.

## Verification

- Build: `nix build .#nixosConfigurations.lindberg-webapps.config.system.build.toplevel`
- Deploy: `deploy --skip-checks .#lindberg-webapps.system-vm`
- All: `nix flake check`
