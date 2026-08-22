# Storage Metrics Plan

Design doc for closing the storage-health metrics gaps surfaced while building
the "Storage" dashboard in `qo.is/dashboards`. This is a plan, not an
implementation — none of the telegraf/NixOS changes below are applied yet.

## What's already collected

Audited by evaluating the actual rendered telegraf config and live Prometheus
data (not just grepping this repo — the relevant plugins are wired up one
level down, in `inputs.srvos.nixosModules.mixins-telegraf`, specifically
`nixos/mixins/telegraf.nix`):

- **Disk usage/inodes** (`inputs.disk`) and **disk IO** (`inputs.diskio`) —
  every host, all filesystem types.
- **SMART health** (`inputs.smart`, via a setuid `smartctl` wrapper) — every
  non-VM host (`calanda`, `lindberg`, `cyprianspitz`), normalized fields like
  `smart_device_health_ok`, `smart_device_reallocated_sectors_count`,
  `smart_device_percentage_used` (NVMe wear), etc.
- **mdraid array status** (`inputs.mdstat`) — any host with
  `boot.swraid.enable = true` (`lindberg`, `cyprianspitz`): disk counts
  (`DisksActive`/`DisksFailed`/`DisksDown`/`DisksSpare`/`DisksTotal`) and
  resync/recovery progress (`BlocksSyncedPct`/`Speed`/`FinishTime`).
- **ZFS pool metrics** (`inputs.zfs`) — enabled fleet-wide but currently inert,
  no ZFS pools exist in this fleet (everything is btrfs/vfat/virtiofs).
- **ext4 error count** — a custom `[[inputs.file]]` reading
  `/sys/fs/ext4/*/errors_count` (`nixos-modules/telegraf/default.nix`). Only
  one host (`lindberg-build`) reports this metric at all; worth confirming
  during implementation whether that host genuinely has an ext4 filesystem
  somewhere or whether this is a stale glob match — not a new plan item
  either way.

None of this required any change in this repo to discover; it's documented
here because it wasn't visible from a repo-only grep for `mdstat`/`smart`, and
the next person debugging "why isn't there SMART data" should start at
`inputs.srvos`, not this repo's telegraf module.

## Gap 1: Btrfs device health (the main gap)

Btrfs is the filesystem on nearly every host (`calanda`, `cyprianspitz`,
`lindberg`, `lindberg-build`, `lindberg-webapps`, `lindberg-nextcloud` all have
btrfs root and/or data volumes). Telegraf has no btrfs plugin — `inputs.disk`
only gives generic used/free/inode numbers, nothing about the two things that
actually indicate btrfs-specific trouble: **device error counters** and
**scrub results**.

Two off-the-shelf options exist and were both rejected:

- [`telegraf-exec-btrfs-status`](https://github.com/iwvelando/telegraf-exec-btrfs-status) —
  covers device stats and scrub status, but it's an unmaintained personal Go
  project, not packaged in nixpkgs; vendoring it means either `buildGoModule`
  against a pinned fork or hand-maintaining the binary ourselves.
- [`telegraf-btrfs-collector`](https://github.com/matthiasstraka/telegraf-btrfs-collector) —
  Python, packaged nowhere either, and only covers `btrfs filesystem df`
  allocation data, not error counters or scrub status — doesn't actually
  close the gap.

**Recommendation**: a small `inputs.exec` script, following the exact pattern
already in this repo (`nixos-modules/telegraf/monitoring.nix`'s
`forgejo-build-status` script — `pkgs.writeShellScript` producing Influx line
protocol, wired into `services.telegraf.extraConfig.inputs.exec`). No new
dependency, no unmaintained upstream to track, and `btrfs device stats -c` is
already machine-parseable (`[/dev/sda1].write_io_errs    0` per line) so the
parsing logic is trivial. Sketch:

```nix
exec = [
  {
    commands = [
      "${pkgs.writeShellScript "btrfs-status" ''
        set -uo pipefail
        for mnt in $(${pkgs.util-linux}/bin/findmnt -t btrfs -n -o TARGET); do
          dev=$(${pkgs.util-linux}/bin/findmnt -n -o SOURCE "$mnt")
          ${pkgs.btrfs-progs}/bin/btrfs device stats -c "$mnt" 2>/dev/null | \
            while read -r path errs; do
              field=$(basename "$path" | tr -d '[]' | sed 's/.*\.//')
              echo "btrfs_device_errors,device=${"$"}{path%%.*},mount=$mnt $field=${"$"}{errs}i"
            done
          scrub=$(${pkgs.btrfs-progs}/bin/btrfs scrub status -R "$mnt" 2>/dev/null)
          # parse `scrub` for last status/errors/duration, emit btrfs_scrub,mount=$mnt ...
        done
      ''}"
    ];
    timeout = "30s";
    interval = "5m";
    data_format = "influx";
  }
];
```

(Illustrative — needs the actual `btrfs scrub status` field parsing filled in
and testing against a real btrfs filesystem before landing.) Emits two
measurements: `btrfs_device_errors` (per-device write/read/flush/corruption/
generation error counts — feed straight into `SmartErrors`-style alerting) and
`btrfs_scrub` (last scrub state/duration/errors-found per mountpoint).

This also depends on scrubs actually running (see Gap 3) — device stats are
cumulative and always available, but scrub results are only as fresh as the
last scrub.

## Gap 2: mdraid silent-corruption detection (`mismatch_cnt`)

`DisksFailed`/`DisksDown` only catch *hard* failures — a drive that mdadm has
already kicked out. They can't see a disk that's still "up" but silently
returning bad data, which is exactly what periodic RAID checks and
`/sys/block/mdX/md/mismatch_cnt` are for. This isn't collected today.

**Recommendation**: mirror the existing `ext4_errors_count` pattern exactly —
another `[[inputs.file]]` entry:

```nix
file = [
  { files = [ "/sys/fs/ext4/*/errors_count" ]; name_override = "ext4_errors"; }
  { files = [ "/sys/block/*/md/mismatch_cnt" ]; name_override = "mdraid_mismatch_count"; }
];
```

Zero new logic — same mechanism already proven in this repo, just a second
glob.

This is only meaningful if periodic RAID checks actually run (a `check`
action has to scan the array for `mismatch_cnt` to change). Worth verifying
during implementation whether that already happens —
`nixos-configurations/cyprianspitz/filesystems.nix` has a literal
`# TODO: RAID Monitoring` comment next to its `mdadmConf`, which suggests it
currently doesn't. If not, add a periodic systemd timer writing `check` to
`/sys/block/mdX/md/sync_action` (standard practice is monthly, staggered
across arrays to avoid simultaneous IO load).

## Gap 3: Btrfs scrub isn't scheduled anywhere

`services.btrfs.autoScrub.enable` exists in nixpkgs (confirmed present,
currently unused here — the repo enables ZFS's equivalent conceptually but no
ZFS pools exist) and isn't turned on for any btrfs filesystem in this fleet.
Without periodic scrubs, `btrfs_device_errors` (Gap 1) will stay flat even in
the presence of real corruption, since scrubs are what actively re-read and
verify data against checksums — device stats only count errors encountered
during normal IO. Recommend enabling `services.btrfs.autoScrub` alongside the
Gap 1 collector, scoped to the mountpoints that matter (`/`, `/mnt/data`,
`/mnt/backup`, etc. — confirm per-host during implementation).

## Known-broken alert rules (documented, not fixed here)

Found while cross-referencing metric names against the alert rules that
consume them (`inputs.srvos`'s `nixos/roles/prometheus/default-alerts.nix`,
imported via `nixos-modules/prometheus/default.nix`):

- `MdRaidDegradedDisks` — `expr = "mdstat_degraded_disks > 0"`. That metric
  doesn't exist; the real telegraf `mdstat` fields are `mdstat_DisksFailed`
  and `mdstat_DisksDown` (PascalCase field names, not `degraded_disks`). This
  alert has never fired and never will as written.
- `UnusualDiskWriteLatency` — `expr = "... / rate(diskio_write[1m]) ..."`.
  The real metric is `diskio_writes` (plural). Same problem.

Both are upstream (srvos), not this repo, so fixing them means either
patching srvos or overriding/replacing the rule in
`nixos-modules/prometheus/`. Out of scope for this plan; flagged so it doesn't
get rediscovered from scratch later.

## Explicitly not planned

- **LVM/thin-pool metrics** — no evidence of thin-provisioning in this fleet;
  the `dm-*` devices observed are plain LVM LVs already fully covered by
  `inputs.disk`'s mounted-filesystem view.
- **ext4-specific work beyond what exists** — no real ext4 filesystems in the
  current fleet (all btrfs/vfat/virtiofs); the one `ext4_errors_value` data
  point is worth a sanity check, not new collection work.
- **SMART self-test log parsing** — `smartd` already runs periodic self-tests
  and mails `sysadmin@qo.is` on failure; exporting the same as a metric is
  marginal value given the mail alerting already exists. Could revisit if the
  dashboard ever needs a "last self-test result" column, but not now.
