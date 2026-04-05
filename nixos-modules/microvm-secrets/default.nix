{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.qois.microvm-secrets;

  secretSubmodule = types.submodule {
    options = {
      generator = mkOption {
        type = types.str;
        default = "${pkgs.pwgen}/bin/pwgen -s 32 1";
        description = "Shell command that outputs the secret value to stdout.";
      };
      fileName = mkOption {
        type = types.str;
        default = "private";
        description = "Name of the file inside the secret directory.";
      };
      services = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "MicroVM names that need this secret. The secret will be generated before these VMs start.";
      };
    };
  };
in
{
  options.qois.microvm-secrets = {
    enable = mkEnableOption "microvm secret generation";

    secrets = mkOption {
      type = types.attrsOf secretSubmodule;
      default = { };
      description = "Secrets to generate on the host and share with microVMs via virtiofs.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services = mapAttrs' (
      secretName: secretCfg:
      nameValuePair "microvm-secret-${secretName}" {
        description = "Generate microvm secret: ${secretName}";
        wantedBy = [ "multi-user.target" ];
        before = map (s: "microvm@${s}.service") secretCfg.services;
        unitConfig.ConditionPathExists = "!/dev/shm/microvm-secrets/${secretName}/${secretCfg.fileName}";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          mkdir -p /dev/shm/microvm-secrets/${secretName}
          ${secretCfg.generator} > /dev/shm/microvm-secrets/${secretName}/${secretCfg.fileName}
          chmod 400 /dev/shm/microvm-secrets/${secretName}/${secretCfg.fileName}
          chmod 500 /dev/shm/microvm-secrets/${secretName}
        '';
      }
    ) cfg.secrets;

    # Share secrets into guest VMs via virtiofs
    microvm.vms =
      let
        # { serviceName = [ "secretName" ... ]; }
        secretsByService = pipe cfg.secrets [
          (mapAttrsToList (
            secretName: secretCfg: map (vmName: nameValuePair vmName secretName) secretCfg.services
          ))
          concatLists
          (groupBy (pair: pair.name))
          (mapAttrs (_: map (pair: pair.value)))
        ];
      in
      mapAttrs (_vmName: secretNames: {
        config.microvm.shares = map (secretName: {
          tag = "secret-${secretName}";
          source = "/dev/shm/microvm-secrets/${secretName}";
          mountPoint = "/run/microvm-secrets/${secretName}";
          proto = "virtiofs";
        }) secretNames;
      }) secretsByService;
  };
}
