{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mapAttrsToList
    mkOption
    ;
  inherit (lib.types) listOf str anything;
  cfg = config.qois.telegraf.monitoring;
  backplaneNet = config.qois.meta.network.virtual.backplane;
  backplaneHostnames = mapAttrsToList (
    name: _host: "${name}.${backplaneNet.domain}"
  ) backplaneNet.hosts;
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
  };

  config = mkIf cfg.enable {
    services.telegraf.extraConfig.inputs = {
      inherit (cfg) http_response;

      ping = map (host: {
        interval = cfg.pingInterval;
        count = 1;
        method = "native";
        urls = [ host ];
      }) cfg.ping;

      exec = map (b: {
        commands = [
          "${pkgs.writeShellScript "forgejo-build-status-${b.repo}-${b.branch}" ''
            set -uo pipefail
            response=$(${pkgs.curl}/bin/curl -sf "https://git.qo.is/api/v1/repos/${b.owner}/${b.repo}/commits/${b.branch}/status")
            if [ $? -ne 0 ] || [ -z "$response" ]; then
              echo 'forgejo_build_status,owner=${b.owner},repo=${b.repo},branch=${b.branch},state=unreachable value=1i'
              exit 0
            fi
            state=$(echo "$response" | ${pkgs.jq}/bin/jq -r '.state // "unknown"')
            case "$state" in
              success) code=0 ;;
              pending) code=1 ;;
              warning) code=2 ;;
              failure|error) code=3 ;;
              *) code=4 ;;
            esac
            echo "forgejo_build_status,owner=${b.owner},repo=${b.repo},branch=${b.branch},state=$state value=''${code}i"
          ''}"
        ];
        timeout = "10s";
        interval = "5m";
        data_format = "influx";
      }) cfg.buildStatus;
    };
  };
}
