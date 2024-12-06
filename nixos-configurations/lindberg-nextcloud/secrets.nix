{ ... }:
let
  backupConfiguration = {
    restartUnits = [
      "borgbackup-job-system-cyprianspitz.service"
      "borgbackup-job-system-tierberg.service"
    ];
  };
in

{
  sops.secrets = {
    "backup/system/password" = backupConfiguration;
    "backup/system/ssh-key" = backupConfiguration;
    "nextcloud/admin" = { };
  };
}
