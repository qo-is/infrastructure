{ config, pkgs, ... }:

let
  vnet = config.qois.meta.network.virtual.backplane.hosts;
  systemTargets = [
    "tierberg"
  ];
  systemJobs = builtins.listToAttrs (
    map (backupHost: {
      name = "system-${backupHost}";
      value = {
        repo = "borg@${vnet.${backupHost}.v4.ip}:.";
        environment.BORG_RSH = "ssh -i /secrets/backup/system/ssh-key";

        paths = [
          "/etc"
          "/home"
          "/var"
          "/secrets"
        ];
        exclude = [
          "/var/tmp"
          "/var/cache"
          "/var/lib/atticd"
          "/var/cache/nginx/nixpkgs-cache"
        ];

        doInit = false;
        encryption = {
          mode = "repokey";
          passCommand = "cat /secrets/backup/system/password";
        };

        startAt = "07:06";
        persistentTimer = true;
      };
    }) systemTargets
  );
in
{
  services.borgbackup.jobs = systemJobs;
}
