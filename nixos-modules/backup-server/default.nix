{
  config,
  lib,
  options,
  ...
}:

let
  inherit (lib)
    attrNames
    filter
    listToAttrs
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    ;
  inherit (lib.types) str;
  cfg = config.qois.backup-server or { };
  snapshotRetentionSeconds = 31 * 24 * 3600;
in
{
  options.qois.backup-server = {
    enable = mkEnableOption "Enable backup hosting";

    backupStorageRoot = mkOption {
      type = str;
      default = "/mnt/backup";
      example = "/mnt/nas/backup";
      description = ''
        Path where backups are stored if this host is used as a backup target.
        Must be a btrfs subvolume containing a `.snapshots` subvolume,
        where snapper keeps weekly read-only snapshots of it.
      '';
    };

    hosts = options.qois.meta.hosts // {
      default = config.qois.meta.hosts;
    };
  };

  config = mkIf cfg.enable {
    services.borgbackup.repos =
      let
        hasSshKey = hostName: cfg.hosts.${hostName}.sshKey != null;
        mkRepo =
          hostName:
          let
            name = "system-${hostName}";
          in
          nameValuePair name {
            path = "${cfg.backupStorageRoot}/${name}";
            authorizedKeys = [ cfg.hosts.${hostName}.sshKey ];
          };
      in
      listToAttrs (map mkRepo (filter hasSshKey (attrNames cfg.hosts)));

    services.snapper = {
      snapshotInterval = "weekly";
      persistentTimer = true;
      configs.backup = {
        SUBVOLUME = cfg.backupStorageRoot;
        TIMELINE_CREATE = true;
        TIMELINE_CLEANUP = true;
        TIMELINE_MIN_AGE = snapshotRetentionSeconds;
        TIMELINE_LIMIT_HOURLY = 0;
        TIMELINE_LIMIT_DAILY = 0;
        TIMELINE_LIMIT_WEEKLY = 0;
        TIMELINE_LIMIT_MONTHLY = 0;
        TIMELINE_LIMIT_QUARTERLY = 0;
        TIMELINE_LIMIT_YEARLY = 0;
      };
    };

    systemd.tmpfiles.settings.backup-snapshots."${cfg.backupStorageRoot}/.snapshots".z = {
      mode = "0750";
      user = "root";
      group = "root";
    };

    qois.telegraf.periodicJobs = [ "snapper-timeline.service" ];
  };
}
