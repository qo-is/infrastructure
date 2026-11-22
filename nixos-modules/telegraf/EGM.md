# telegraf

## Overview

Telegraf metrics agent exposing Prometheus-format metrics on port 9273. SMART, mdstat, ZFS and disk inputs come from the srvos `mixins-telegraf` module imported here, not from this directory. Legacy notes in [README](./README.md). Tested by `test.nix` / `test.py`.

## Interface

- `qois.telegraf.enable` (bool) [default.nix:options.qois.telegraf.enable]
- `qois.telegraf.serviceInputs` (TOML attrs, default `{ }`; inputs contributed by service modules) [default.nix:options.qois.telegraf.serviceInputs]
- `qois.telegraf.periodicJobs` (listOf str, default `[ ]`; oneshot units to monitor) [default.nix:options.qois.telegraf.periodicJobs]
- `qois.telegraf.periodicJobsInterval` (str, default `"1m"`) [default.nix:options.qois.telegraf.periodicJobsInterval]
- `qois.telegraf.btrfsInterval` (str, default `"1m"`) [btrfs.nix:options.qois.telegraf.btrfsInterval]
- `qois.telegraf.fwupdInterval` (str, default `"5m"`) [fwupd.nix:options.qois.telegraf.fwupdInterval]
- `qois.telegraf.monitoring.enable` (bool); `http_response` (default checks of cloud, git, vault, monitoring, attic), `ping` (default backplane hosts), `pingInterval` (`"1m"`), `buildStatus` (default `qo.is/infrastructure` `main`), `buildStatusUrl` (`https://git.qo.is`), `buildStatusInterval` (`"5m"`) [monitoring.nix:options.qois.telegraf.monitoring]
- Scripts: `systemd-job-status` [default.nix:systemdJobStatus], `btrfs-stats` [btrfs-stats.sh] (metrics `btrfs_device_errors`, `btrfs_allocation`, `btrfs_space`, `btrfs_commits`), `fwupd-updates` [fwupd-updates.sh] (`fwupd_updates`), `forgejo-build-status` [forgejo-build-status.sh] (`forgejo_build_status`)

## Invariants

- `serviceInputs` is merged into `services.telegraf.extraConfig.inputs` regardless of `enable`, and has the same type as `extraConfig` so declarations concatenate [default.nix:config]
- The `systemd_job` exec input exists only if `periodicJobs` is non-empty; emits `success`, `last_success_timestamp` and, for timer-triggered jobs, `next_execution_gap_seconds` [default.nix:systemdJobStatus]
- btrfs collection requires `boot.supportedFilesystems.btrfs`; fwupd collection requires `services.fwupd.enable` [btrfs.nix:config] [fwupd.nix:config]
- fwupd exit code 2 ("nothing to do") is treated as success [fwupd-updates.sh:nothing_to_do]
- Forgejo state maps success 0, pending 1, warning 2, failure/error 3, other 4 [forgejo-build-status.sh]
- The nginx input is forced to the local `/nginx_status` URL when `statusPage` is on [default.nix:inputs.nginx.urls]

## Side Effects

- Opens TCP 9273 on `wg-backplane` [default.nix:networking.firewall.interfaces]
- Enables `services.telegraf` with cpu, net, nginx and systemd_units inputs, `prometheus_client` output with 10m expiration [default.nix:services.telegraf]
- fwupd module adds `fwupd-refresh.service` to `periodicJobs` [fwupd.nix:qois.telegraf.periodicJobs]
- Monitoring performs HTTP probes, native ICMP pings and Forgejo API calls [monitoring.nix:services.telegraf.extraConfig]

## Verification

- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-telegraf`
- Run: `nix flake check`
