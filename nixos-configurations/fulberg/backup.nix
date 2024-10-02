{ config, pkgs, ... }:
{

  qois.backup-server = {
    enable = true;
    backupStorageRoot = "/mnt/nas/backup";
  };

  services.borgbackup.repos =
    let
      backupRoot = "/mnt/nas/backup";
      hostBackupRoot = "${backupRoot}/hosts";
      dataBackupRoot = "${backupRoot}/data";
    in
    {
      "lindberg-nextcloud" = {
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIpzfp9VqclbPJ42ZrkRpvjMSTeyq0qce03zCRXqIHMw backup@lindberg-nextcloud"
        ];
        path = "${hostBackupRoot}/lindberg-nextcloud";
      };
      "lindberg-data" = {
        authorizedKeys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGTmyoVONC12MgOodvzdPpZzLSVwpkC6zkf+Rg0W36gy backup-data@lindberg"
        ];
        path = "${dataBackupRoot}/lindberg";
      };
      "lindberg-build-system" = {
        authorizedKeys = [
          "ssh-ed25519 AAAATODOTODOTODONTE5AAAAIGTmyoVONC12MgOodvzdPpZzLSVwpkC6zkf+Rg0W36gy backup-system@lindberg-build"
        ];
        path = "${dataBackupRoot}/lindberg-build-system";
      };
    };
}
