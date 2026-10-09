{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    boolToString
    mkAfter
    mkIf
    mkOption
    ;
  inherit (lib.types) bool str;
  inherit (pkgs) curl jq writeShellApplication;

  cfg = config.qois.kanidm;
  provision = config.services.kanidm.provision;

  settings = (pkgs.formats.json { }).generate "kanidm-domain-settings.json" {
    url = provision.instanceUrl;
    inherit (provision) acceptInvalidCerts;
    authAccount = "admin";
    attributes = {
      domain_display_name = cfg.displayName;
      domain_allow_account_recovery = boolToString cfg.allowAccountRecovery;
    };
  };

  setDomainSettings = writeShellApplication {
    name = "kanidm-set-domain-settings";
    runtimeInputs = [
      curl
      jq
    ];
    text = builtins.readFile ./kanidm-api.sh + builtins.readFile ./domain-settings.sh;
  };
in
{
  options.qois.kanidm = {
    displayName = mkOption {
      type = str;
      default = cfg.domain;
      defaultText = "config.qois.kanidm.domain";
      description = "Name of the instance, shown on the login pages and in sent messages.";
    };

    allowAccountRecovery = mkOption {
      type = bool;
      default = cfg.mailSender.enable;
      defaultText = "config.qois.kanidm.mailSender.enable";
      description = ''
        Whether persons may request a credential reset link to one of their mail
        addresses from the login page.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.kanidm.serviceConfig.ExecStartPost = mkAfter [
      "${setDomainSettings}/bin/kanidm-set-domain-settings ${settings} ${cfg.adminPasswordFile}"
    ];
  };
}
