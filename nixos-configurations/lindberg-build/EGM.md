# lindberg-build

## Overview

Build/CI VM on lindberg (qemu guest). Deployed in the `system-ci` category because `qois.git-ci-runner` is enabled (selected in `deploy/system-ci/default.nix`).

## Interface

- Imports: [default.nix:imports] `./applications`, `./disko-config.nix`, `./networking.nix`, `./secrets.nix`.
- `qois.system.virtual-machine.enable = true`; `system.stateVersion = "26.05"` [default.nix].
- Hostname from `meta.hosts.lindberg-build.hostName`, DHCP on `enp11s0`, `qois.backplane-net.enable`, tcp 80/443 open [networking.nix].
- Disks via disko: `/dev/vda` GPT with BIOS boot and btrfs (`/nix` zstd, `/` root), `/dev/vdb` ext4 at `/var/cache/nginx/nixpkgs-cache`, `/dev/vdc` swap [disko-config.nix:disko.devices.disk].
- sops secret `gitlab-runner/default-registration` (restarts `gitlab-runner.service`) [secrets.nix].
- Children: [applications](./applications/EGM.md).

## Invariants

- Device names `/dev/vda..vdc` and `enp11s0` must match the VM definition [disko-config.nix; networking.nix].

## Side Effects

- Reads CI runner registration secret [secrets.nix].

## Verification

- Build: `nix build .#nixosConfigurations.lindberg-build.config.system.build.toplevel`
- Deploy: `deploy --skip-checks .#lindberg-build.system-ci`
- All: `nix flake check`
