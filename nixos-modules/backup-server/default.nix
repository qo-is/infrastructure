{
  config,
  lib,
  options,
  ...
}:

let
  cfg = config.qois.backup-server or { };
in
with lib;
{
  options.qois.backup-server = {
    enable = mkEnableOption "Enable backup hosting";

    backupStorageRoot = mkOption {
      type = with types; nullOr str;
      default = "/mnt/backup";
      example = "/mnt/nas/backup";
      description = "Path where backups are stored if this host is used as a backup target.";
    };

    hosts = options.qois.meta.hosts // {
      default = config.qois.meta.hosts;
    };
  };

  config = lib.mkIf cfg.enable {
    services.borgbackup.repos =
      let
        hasSshKey = hostName: cfg.hosts.${hostName}.sshKey != null;
        mkRepo =
          hostName:
          (
            let
              name = "system-${hostName}";
            in
            {
              inherit name;
              value = {
                path = "${cfg.backupStorageRoot}/${name}";
                authorizedKeys = [ cfg.hosts.${hostName}.sshKey ];
              };
            }
          );

        hostsWithSshKeys = lib.filter hasSshKey (lib.attrNames cfg.hosts);
      in
      lib.listToAttrs (map mkRepo hostsWithSshKeys);
  };
}
