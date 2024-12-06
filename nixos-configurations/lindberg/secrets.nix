{ ... }:
let
  backupConfiguration = {
    restartUnits = [
      "borgbackup-job-data-cyprianspitz.service"
      "borgbackup-job-data-tierberg.service"
    ];
  };
in

{
  sops.secrets = {
    "tailscale/key" = {
      restartUnits = [ "tailscale.service" ];
    };
    "backup/data/password" = backupConfiguration;
    "backup/data/ssh-key" = backupConfiguration;
  };
}
