{ config, lib, ... }:
let
  inherit (lib) mkIf;
  unallocatedLow = "btrfs_space_unallocated < 3 * 1024 ^ 3";
in
{
  config = mkIf config.qois.alertmanager.enable {
    srvos.prometheus.ruleGroups = {
      # systemd forgets exit timestamps on reboot, max_over_time keeps the last success visible.
      qoisPeriodicJobs.alertRules.PeriodicJobNotSucceeded = {
        expr = "systemd_job_success unless on(host, name) (time() - max_over_time(systemd_job_last_success_timestamp[30h]) < 30 * 3600)";
        for = "1h";
        annotations.description = "{{$labels.host}}: {{$labels.name}} has not exited successfully in the last 30h";
      };

      qoisBuilds.alertRules.BuildNotSucceeded = {
        expr = "forgejo_build_status_value unless on(owner, repo, branch) (time() - max_over_time(forgejo_build_status_last_success_timestamp[3d]) < 3 * 86400)";
        for = "1h";
        annotations.description = "{{$labels.owner}}/{{$labels.repo}}#{{$labels.branch}} has had no successful build in the last 3 days";
      };

      qoisFilesystems.alertRules = {
        BtrfsDeviceErrors = {
          expr = ''label_replace({__name__=~"btrfs_device_errors_.+"} > 0, "counter", "$1", "__name__", "btrfs_device_errors_(.+)")'';
          annotations.description = "{{$labels.host}}: btrfs {{$labels.label}} ({{$labels.fsid}}) device {{$labels.devid}} reports {{$value}} {{$labels.counter}}: check `btrfs device stats`, reset with `btrfs device stats -z` once resolved";
        };
        BtrfsUnallocatedLow = {
          expr = unallocatedLow;
          for = "15m";
          annotations.description = "{{$labels.host}}: btrfs {{$labels.label}} ({{$labels.fsid}}) has only {{$value | humanize1024}}B unallocated: run `btrfs balance start -dusage=50`";
        };
        BtrfsMetadataNearlyFull = {
          expr = ''btrfs_allocation_bytes_used{type="metadata"} / btrfs_allocation_total_bytes{type="metadata"} > 0.9 and on(host, fsid) ${unallocatedLow}'';
          for = "15m";
          annotations.description = "{{$labels.host}}: btrfs {{$labels.label}} ({{$labels.fsid}}) metadata is {{$value | humanizePercentage}} full and no space is left to allocate more";
        };
        FilesystemReadOnly = {
          expr = ''disk_total{mode="ro", path!="/nix/store"}'';
          for = "5m";
          annotations.description = "{{$labels.host}}: {{$labels.path}} ({{$labels.fstype}}) is mounted read-only, likely after filesystem errors";
        };
      };

      qoisFirmware.alertRules.FwupdUpdatesAvailable = {
        expr = "fwupd_updates_devices > 0";
        for = "7d";
        annotations.description = "{{$labels.host}}: {{$value}} devices have firmware updates pending for 7 days: run `fwupdmgr update`";
      };
    };
  };
}
