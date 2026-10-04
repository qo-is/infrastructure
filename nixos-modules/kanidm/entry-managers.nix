{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    attrNames
    elem
    filterAttrs
    mapAttrs
    mkAfter
    mkIf
    mkOption
    ;
  inherit (lib.types) attrsOf str;
  inherit (pkgs) curl jq writeShellApplication;

  cfg = config.qois.kanidm;
  provision = config.services.kanidm.provision;

  parentsOf =
    group: attrNames (filterAttrs (_name: parent: elem group parent.members) provision.groups);

  settings = (pkgs.formats.json { }).generate "kanidm-entry-managers.json" {
    url = provision.instanceUrl;
    inherit (provision) acceptInvalidCerts;
    groups = mapAttrs (group: manager: {
      inherit manager;
      parents = parentsOf group;
    }) cfg.groupEntryManagers;
  };

  setEntryManagers = writeShellApplication {
    name = "kanidm-set-entry-managers";
    runtimeInputs = [
      curl
      jq
    ];
    text = builtins.readFile ./kanidm-api.sh + builtins.readFile ./entry-managers.sh;
  };
in
{
  options.qois.kanidm.groupEntryManagers = mkOption {
    type = attrsOf str;
    default = {
      sysadmin = "idm_admins";
    };
    description = ''
      Maps a provisioned group to the group managing its members. A group nested in a
      high privilege group like `idm_admins` is itself high privilege; without an entry
      manager, nobody may change its members.
    '';
  };

  config = mkIf cfg.enable {
    systemd.services.kanidm.serviceConfig.ExecStartPost = mkAfter [
      "${setEntryManagers}/bin/kanidm-set-entry-managers ${settings} ${cfg.idmAdminPasswordFile}"
    ];
  };
}
