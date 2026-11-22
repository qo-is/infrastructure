# alertmanager

## Overview

Email alerting through Prometheus Alertmanager, plus the qois-specific Prometheus alert rules (uptime, periodic jobs, builds, filesystems, firmware) layered on the srvos rule groups.

## Interface

- `qois.alertmanager.enable` (bool, default false) [default.nix:enable]
- `qois.alertmanager.emailTo` (str, default `sysadmin@qo.is`) [default.nix:emailTo]
- `qois.alertmanager.routePrefix` (str, default `/alertmanager`, readOnly) [default.nix:routePrefix]
- `qois.alertmanager.msmtpPasswordFile` (path, default `config.sops.secrets."msmtp/password".path`) [default.nix:msmtpPasswordFile]
- Alert rules (only when enabled) in `srvos.prometheus.ruleGroups`: `srvosAlerts.Uptime` (forced override, 60 days), `qoisPeriodicJobs.PeriodicJobNotSucceeded`, `qoisBuilds.BuildNotSucceeded`, `qoisFilesystems.{BtrfsDeviceErrors,BtrfsUnallocatedLow,BtrfsMetadataNearlyFull,FilesystemReadOnly}`, `qoisFirmware.FwupdUpdatesAvailable` [alert-rules.nix:srvos.prometheus.ruleGroups]

## Invariants

- Alertmanager listens on `127.0.0.1` only; its external URL is `https://${config.qois.prometheus.domain}${routePrefix}/` [default.nix:listenAddress, webExternalUrl]
- SMTP uses `mail.cyon.ch:587` with `smtp_require_tls = true`, from `monitoring@qo.is`, auth user `system@qo.is` [default.nix:global]
- Route groups by `alertname` and `host`; group_wait 30s, group_interval 5m, repeat_interval 12h; single `email` receiver with `send_resolved = true` [default.nix:route, receivers]
- Rules are only defined when `qois.alertmanager.enable` is set [alert-rules.nix:mkIf]
- Prometheus is pointed at the local alertmanager with `path_prefix = routePrefix` [default.nix:services.prometheus.alertmanagers]

## Side Effects

- Enables `services.prometheus.alertmanager` [default.nix:config]
- Declares group `postdrop` and adds it as supplementary group of `alertmanager.service` [default.nix:users.groups.postdrop, systemd.services.alertmanager]
- Reads the `msmtp/password` sops secret (default) [default.nix:msmtpPasswordFile]

## Verification

- Run: `nix flake check`
- Run: `nix build .#checks.x86_64-linux.nixos-modules.entries.vm-test-run-alertmanager` (test exists in `./test.nix`, `./test.py`)
