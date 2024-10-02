{ config, pkgs, ... }:
{

  qois.backup-client.includePaths = [ "/mnt/data" ];

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
