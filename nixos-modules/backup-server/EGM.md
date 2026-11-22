# backup-server

## Overview

Hosts borg repositories for each host that has an SSH key and keeps weekly read-only btrfs snapshots of the storage root via snapper. See [legacy README](./README.md); clients use [backup-client](../backup-client/EGM.md).

## Interface

- `qois.backup-server.enable` (bool, default false) [default.nix:enable]
- `qois.backup-server.backupStorageRoot` (str, default `/mnt/backup`) [default.nix:backupStorageRoot]
- `qois.backup-server.hosts` (type of `qois.meta.hosts`, default `config.qois.meta.hosts`) [default.nix:hosts]

## Invariants

- `backupStorageRoot` must be a btrfs subvolume containing a `.snapshots` subvolume [default.nix:backupStorageRoot description]
- One repo `system-<host>` at `${backupStorageRoot}/system-<host>` per host with non-null `sshKey`, authorised with that key [default.nix:services.borgbackup.repos]
- Snapper config `backup`: weekly timeline, `TIMELINE_MIN_AGE` of 31 days, all hourly..yearly limits 0, so snapshots are removed once older than 31 days [default.nix:services.snapper, snapshotRetentionSeconds]
- `.snapshots` is root:root mode 0750 [default.nix:systemd.tmpfiles.settings.backup-snapshots]

## Side Effects

- Creates borg repos (and the `borg` SSH access they imply) [default.nix:services.borgbackup.repos]
- Enables snapper timeline for `backupStorageRoot` [default.nix:services.snapper]
- Registers `snapper-timeline.service` as telegraf periodic job [default.nix:qois.telegraf.periodicJobs]

## Verification

- Run: `nix flake check`
- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-backup-server` (test in `./test.nix`, `./test.py`)
