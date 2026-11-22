# backup-client

## Overview

Host-based borg backup jobs `system-<target>` to backup-server hosts over a virtual network. Other modules append to `includePaths`. See [legacy README](./README.md); targets use the [backup-server](../backup-server/EGM.md) module.

## Interface

- `qois.backup-client.enable` (bool, default false) [default.nix:enable]
- `qois.backup-client.targets` (listOf enum of `qois.meta.hosts` names, default `[ "cyprianspitz" ]`) [default.nix:targets]
- `qois.backup-client.includePaths` (listOf str, default `[ ]`) [default.nix:includePaths]
- `qois.backup-client.excludePaths` (listOf str, default `[ ]`) [default.nix:excludePaths]
- `qois.backup-client.passwordFile` (nullOr str, default null, falls back to sops `system/backup/password`) [default.nix:passwordFile]
- `qois.backup-client.networkName` (enum of `qois.meta.network.virtual` names, default `backplane`) [default.nix:networkName]

## Invariants

- Always included: `/etc`, `/home`, `/root`; always excluded: `/root/.cache`, `/root/.config/borg` [default.nix:defaultIncludePaths, defaultExcludePaths]
- Job name is `system-${backupHost}`; repo is `borg@<target v4 ip>:.`; SSH uses `/etc/ssh/ssh_host_ed25519_key` [default.nix:services.borgbackup.jobs, BORG_RSH]
- Encryption is `repokey`, passphrase read with `cat <passFile>`; `doInit = true` [default.nix:encryption]
- Schedule `07:06` daily, persistent [default.nix:startAt, persistentTimer]
- Prune keeps: within 14d, 4 weekly, 6 monthly, all yearly (`-1`) [default.nix:prune.keep]
- Jobs are only created when `enable` is set; the telegraf periodic-job registration is unconditional over existing jobs [default.nix:config.services.borgbackup.jobs, config.qois.telegraf.periodicJobs]

## Side Effects

- Creates borg jobs and systemd units `borgbackup-job-system-<target>.service` [default.nix:services.borgbackup.jobs]
- Registers every borgbackup job unit as `qois.telegraf.periodicJobs` [default.nix:qois.telegraf.periodicJobs]
- When enabled without `passwordFile`, declares sops secret `system/backup/password` restarting the job units [default.nix:config.sops.secrets]
- Network access to targets over SSH [default.nix:repo]

## Verification

- Run: `nix flake check`
