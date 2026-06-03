{ ... }:
{

  qois.backup-client.includePaths = [
    "/mnt/data"
    "/var/lib/jellyfin"
    "/var/lib/nixos-containers"
  ];
  qois.backup-client.excludePaths = [ "/var/lib/jellyfin/data/transcodes" ];

  services.borgbackup.jobs = {
    data-local = {
      repo = "/mnt/backup/disks/data";
      doInit = true;
      paths = [ "/mnt/data/" ];
      prune.keep = {
        within = "14d";
        weekly = 4;
        monthly = 6;
        yearly = -1;
      };
      encryption = {
        mode = "authenticated";
        passphrase = "";
      };
      startAt = "07:15";
    };
  };
}
