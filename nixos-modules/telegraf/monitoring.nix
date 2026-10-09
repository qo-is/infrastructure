{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    escapeShellArgs
    getExe
    mkEnableOption
    mkIf
    mapAttrsToList
    mkOption
    readFile
    ;
  inherit (lib.types) listOf str anything;
  inherit (pkgs) curl jq writeShellApplication;
  cfg = config.qois.telegraf.monitoring;
  backplaneNet = config.qois.meta.network.virtual.backplane;
  backplaneHostnames = mapAttrsToList (
    name: _host: "${name}.${backplaneNet.domain}"
  ) backplaneNet.hosts;

  forgejoBuildStatus = writeShellApplication {
    name = "forgejo-build-status";
    runtimeInputs = [
      curl
      jq
    ];
    text = readFile ./forgejo-build-status.sh;
  };
in
{
  options.qois.telegraf.monitoring = {
    enable = mkEnableOption "central blackbox monitoring via telegraf";
    http_response = mkOption {
      type = listOf anything;
      default = [
        {
          urls = [ "https://cloud.qo.is/login" ];
          response_string_match = "Nextcloud";
        }
        {
          urls = [ "https://git.qo.is" ];
          response_string_match = "Forgejo";
        }
        {
          urls = [ "https://vault.qo.is/alive" ];
          response_string_match = "\"20";
        }
        {
          urls = [ "https://monitoring.qo.is/login" ];
          response_string_match = "Grafana";
        }
        {
          urls = [ "https://attic.qo.is" ];
        }
      ];
    };
    ping = mkOption {
      type = listOf str;
      default = backplaneHostnames;
    };
    pingInterval = mkOption {
      type = str;
      default = "1m";
    };
    buildStatus = mkOption {
      type = listOf anything;
      default = [
        {
          owner = "qo.is";
          repo = "infrastructure";
          branch = "main";
        }
      ];
      description = "Forgejo repos/branches to report the latest combined commit status for.";
    };
    buildStatusUrl = mkOption {
      type = str;
      default = "https://git.qo.is";
      description = "Base URL of the Forgejo instance serving the commit status API.";
    };
    buildStatusInterval = mkOption {
      type = str;
      default = "5m";
    };
  };

  config = mkIf cfg.enable {
    services.telegraf.extraConfig = {
      inputs = {
        inherit (cfg) http_response;

        ping = map (host: {
          interval = cfg.pingInterval;
          count = 1;
          method = "native";
          urls = [ host ];
        }) cfg.ping;

        exec = map (b: {
          commands = [
            (escapeShellArgs [
              (getExe forgejoBuildStatus)
              cfg.buildStatusUrl
              b.owner
              b.repo
              b.branch
            ])
          ];
          data_format = "influx";
          interval = cfg.buildStatusInterval;
          timeout = "15s";
        }) cfg.buildStatus;
      };
    };
  };
}
