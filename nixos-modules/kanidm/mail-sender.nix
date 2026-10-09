{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    getExe'
    mkEnableOption
    mkIf
    mkOption
    ;
  inherit (lib.types) path str;
  inherit (pkgs)
    coreutils
    curl
    jq
    systemd
    writeShellApplication
    ;

  cfg = config.qois.kanidm;
  senderCfg = cfg.mailSender;
  provision = config.services.kanidm.provision;
  msmtp = config.programs.msmtp;

  stateDir = builtins.dirOf config.services.kanidm.server.settings.db_path;
  tokenFile = "${stateDir}/mail-sender-token";
  configFile = "mail-sender.toml";

  json = pkgs.formats.json { };
  toml = pkgs.formats.toml { };

  provisioningSettings = json.generate "kanidm-mail-sender-account.json" {
    url = provision.instanceUrl;
    inherit (provision) acceptInvalidCerts;
    account = "mail-sender";
    displayName = "Mail Sender";
    tokenLabel = "mail sender token";
    senderGroup = "idm_message_senders";
    manager = "idm_admins";
  };

  provisionToken = writeShellApplication {
    name = "kanidm-mail-sender-token";
    runtimeInputs = [
      curl
      jq
    ];
    text = builtins.readFile ./kanidm-api.sh + builtins.readFile ./mail-sender-token.sh;
  };

  clientConfig = toml.generate "kanidm-mail-sender-client.toml" {
    uri = "https://${cfg.domain}";
  };

  staticConfig = toml.generate "kanidm-mail-sender-static.toml" {
    instance_display_name = senderCfg.instanceDisplayName;
    instance_url = "https://${cfg.domain}";
    mail_from_address = senderCfg.fromAddress;
    mail_reply_to_address = senderCfg.replyToAddress;
    mail_relay = senderCfg.relay;
    mail_username = senderCfg.username;
  };

  renderConfig = writeShellApplication {
    name = "kanidm-mail-sender-config";
    runtimeInputs = [
      coreutils
      jq
    ];
    text = builtins.readFile ./mail-sender-config.sh;
  };
in
{
  options.qois.kanidm.mailSender = {
    enable = mkEnableOption "delivery of queued kanidm messages, like password resets" // {
      default = config.qois.outgoing-server-mail.enable;
      defaultText = "config.qois.outgoing-server-mail.enable";
    };

    instanceDisplayName = mkOption {
      type = str;
      default = cfg.displayName;
      defaultText = "config.qois.kanidm.displayName";
      description = "Name of the instance, shown in the subject of sent messages.";
    };

    relay = mkOption {
      type = str;
      default = "smtps://${msmtp.accounts.default.host}:${toString msmtp.defaults.port}";
      defaultText = "the smtps URL of the msmtp default account";
      description = "SMTP relay URL. Must be `smtps://` or `smtp://`, which requires STARTTLS.";
    };

    username = mkOption {
      type = str;
      default = msmtp.accounts.default.user;
      defaultText = "config.programs.msmtp.accounts.default.user";
      description = "User to authenticate to the SMTP relay as.";
    };

    passwordFile = mkOption {
      type = path;
      default = config.sops.secrets."msmtp/password".path;
      defaultText = ''config.sops.secrets."msmtp/password".path'';
      description = "Path to a file holding the SMTP relay password.";
    };

    fromAddress = mkOption {
      type = str;
      default = msmtp.accounts.default.from;
      defaultText = "config.programs.msmtp.accounts.default.from";
      description = "Sender address of sent messages.";
    };

    replyToAddress = mkOption {
      type = str;
      default = "sysadmin@qo.is";
      description = "Reply-to address of sent messages.";
    };
  };

  config = mkIf (cfg.enable && senderCfg.enable) {
    systemd.services.kanidm-mail-sender-token = {
      description = "Provision the kanidm mail sender service account and token";
      after = [ "kanidm.service" ];
      requires = [ "kanidm.service" ];
      startAt = "*:0/15";
      serviceConfig = {
        Type = "oneshot";
        User = "kanidm";
        Group = "kanidm";
        ExecStart = "${getExe' provisionToken "kanidm-mail-sender-token"} ${provisioningSettings} ${cfg.idmAdminPasswordFile} ${tokenFile}";
        ProtectSystem = "strict";
        ReadWritePaths = [ stateDir ];
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };

    systemd.paths.kanidm-mail-sender-token-changed = {
      wantedBy = [ "multi-user.target" ];
      pathConfig.PathChanged = tokenFile;
    };

    systemd.services.kanidm-mail-sender-token-changed = {
      description = "Restart the kanidm mail sender with its new token";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${getExe' systemd "systemctl"} try-restart kanidm-mail-sender.service";
      };
    };

    systemd.services.kanidm.serviceConfig.LogFilterPatterns = [
      ''~^[0-9a-f-]{36} INFO +request \[ .* \] method: GET \| uri: /scim/v1/Message/_ready \| .* \| status_code: 200 \|''
      ''~^[0-9a-f-]{36} INFO +┕━ scim_message_ready_search \[ .* \]$''
      ''~^[0-9a-f-]{36} INFO +┕━ ｉ \[info\]: search \| event_tag_id: [0-9]+ \| initiator: User\( mail-sender@''
    ];

    systemd.services.kanidm-mail-sender = {
      description = "Kanidm mail sender";
      wantedBy = [ "multi-user.target" ];
      after = [
        "kanidm.service"
        "kanidm-mail-sender-token.service"
        "nginx.service"
      ];
      wants = [
        "kanidm.service"
        "nginx.service"
      ];
      requires = [ "kanidm-mail-sender-token.service" ];
      serviceConfig = {
        DynamicUser = true;
        RuntimeDirectory = "kanidm-mail-sender";
        LoadCredential = [
          "token:${tokenFile}"
          "mail-password:${senderCfg.passwordFile}"
        ];
        ExecStartPre = "+${getExe' renderConfig "kanidm-mail-sender-config"} ${staticConfig} %t/kanidm-mail-sender/${configFile}";
        ExecStart = "${getExe' cfg.package "kanidm-mail-sender"} --client-config ${clientConfig} --mail-sender-config %t/kanidm-mail-sender/${configFile}";
        Restart = "on-failure";
        RestartSec = 10;
        LogFilterPatterns = [
          "~kanidm_mail_sender.* checking for mail \\.\\.\\.$"
          "~kanidm_mail_sender.* next mail check on [0-9-]+ [0-9:]+ UTC, wait_time = [0-9]+s$"
        ];

        CapabilityBoundingSet = "";
        DeviceAllow = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        PrivateDevices = true;
        PrivateUsers = true;
        ProcSubset = "pid";
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectProc = "invisible";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
        RestrictNamespaces = true;
        RestrictRealtime = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [
          "@system-service"
          "~@privileged @resources"
        ];
        UMask = "0077";
      };
    };
  };
}
