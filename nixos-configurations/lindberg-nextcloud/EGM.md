# lindberg-nextcloud

## Overview

Nextcloud VM on lindberg (`system-vm` category). Nextcloud data lives on lindberg and is mounted via virtiofs.

## Interface

- Imports: [default.nix:imports] `./applications`, `./backup.nix`, `./secrets.nix`.
- `qois.system.virtual-machine.enable`, `srvos.boot.consoles = mkForce [ "tty0" ]`, `system.stateVersion = "26.05"` [default.nix].
- Boot/filesystems: GRUB on `/dev/vda`, btrfs root (`subvol=root`) by UUID [default.nix:boot.loader.grub.device, fileSystems."/"].
- virtiofs mount `data/nextcloud` at `/var/lib/nextcloud` [default.nix:systemd.mounts].
- Hostname from `meta.hosts.lindberg-nextcloud.hostName`, DHCP on `enp2s0`, `qois.backplane-net.enable`, tcp 80/443 open [default.nix].
- Backup: `qois.backup-client.excludePaths = [ "/var/lib/nextcloud/data" ]` [backup.nix].
- sops secrets: `backup/system/password`, `backup/system/ssh-key` (restart `borgbackup-job-system-cyprianspitz.service`), `nextcloud/admin` [secrets.nix].
- Children: [applications](./applications/EGM.md).

## Invariants

- Nextcloud data is excluded from this VM's backup because it is backed up on lindberg [backup.nix].
- The virtiofs share `data/nextcloud` must be provided by the hypervisor [default.nix:systemd.mounts].

## Side Effects

- Mounts a host-shared filesystem and reads sops secrets [default.nix; secrets.nix].

## Verification

- Build: `nix build .#nixosConfigurations.lindberg-nextcloud.config.system.build.toplevel`
- Deploy: `deploy --skip-checks .#lindberg-nextcloud.system-vm`
- All: `nix flake check`
