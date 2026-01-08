{
  config,
  lib,
  ...
}:

let
  cfg = config.qois.backup-client;
  defaultIncludePaths = [
    "/etc"
    "/home"
    "/root"
  ];
  defaultExcludePaths = [
    "/root/.cache"
    "/root/.config/borg"
  ];
  defaultSopsPasswordFile = "system/backup/password";
in
with lib;
{
  options.qois.backup-client =
    let
      pathsType = with types; listOf str;
    in
    {
      enable = mkEnableOption "Enable this host to execute backups.";

      targets = mkOption {
        type = with types; listOf (enum (attrNames config.qois.meta.hosts));
        default = [
          "cyprianspitz"
        ];
        description = "Target hosts to make backups to. Must be configured to receive backups in the backplane network.";
      };

      includePaths = mkOption {
        type = pathsType;
        default = [ ];
        description = "Paths that are included in backup. The backup module always includes: ${concatStringsSep ", " defaultIncludePaths}";
      };

      excludePaths = mkOption {
        type = pathsType;
        default = [ ];
        description = "Paths that are excluded in backup. The backup module always excludes: ${concatStringsSep ", " defaultExcludePaths}";
      };

      passwordFile = mkOption {
        type = with types; nullOr str;
        default = null;
        example = "config.sops.secrets.${defaultSopsPasswordFile}.path";
        description = "Path to password file. Taken from sops host secret ${defaultSopsPasswordFile} by default, must be randomly generated per host.";
      };

      networkName = mkOption {
        type = types.enum (attrNames config.qois.meta.network.virtual);
        default = "backplane";
        description = "Name of virtual network through which the backups should be done";
      };
    };

  config.services.borgbackup.jobs = mkIf cfg.enable (
    builtins.listToAttrs (
      map (backupHost: {
        name = "system-${backupHost}";
        value = {
          repo = "borg@${config.qois.meta.network.virtual.${cfg.networkName}.hosts.${backupHost}.v4.ip}:.";
          environment.BORG_RSH = "ssh -i /etc/ssh/ssh_host_ed25519_key";

          paths = defaultIncludePaths ++ cfg.includePaths;
          exclude = defaultExcludePaths ++ cfg.excludePaths;

          doInit = true;
          encryption = {
            mode = "repokey";
            passCommand =
              let
                passFile =
                  if cfg.passwordFile != null then
                    cfg.passwordFile
                  else
                    config.sops.secrets.${defaultSopsPasswordFile}.path;
              in
              "cat ${passFile}";
          };

          startAt = "07:06";
          persistentTimer = true;
        };
      }) cfg.targets
    )
  );

  config.sops.secrets = mkIf (cfg.enable && cfg.passwordFile == null) {
    ${defaultSopsPasswordFile} = {
      restartUnits = map (target: "borgbackup-job-system-${target}.service") cfg.targets;
    };
  };
}
