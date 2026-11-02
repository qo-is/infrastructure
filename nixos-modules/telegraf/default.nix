{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) concatMapStringsSep escapeShellArg;
  inherit (pkgs) systemd writeShellApplication;
  cfg = config.qois.telegraf;

  systemdJobStatus = writeShellApplication {
    name = "systemd-job-status";
    runtimeInputs = [ systemd ];
    text = ''
      property() {
        systemctl show --timestamp=unix --property="$2" --value "$1"
      }

      nextExecutionGap() {
        local timer nextElapse lastTrigger
        read -r timer _ <<<"$(property "$1" TriggeredBy)"
        [ -n "$timer" ] || return 0
        nextElapse=$(property "$timer" NextElapseUSecRealtime)
        lastTrigger=$(property "$timer" LastTriggerUSec)
        if [ -n "$nextElapse" ] && [ -n "$lastTrigger" ]; then
          printf ',next_execution_gap_seconds=%si' $((''${nextElapse#@} - ''${lastTrigger#@}))
        fi
      }

      for unit in "$@"; do
        exitTimestamp=$(property "$unit" ExecMainExitTimestamp)
        if [ "$(property "$unit" Result)" = success ] && [ -n "$exitTimestamp" ]; then
          fields="success=1i,last_success_timestamp=''${exitTimestamp#@}i"
        else
          fields="success=0i"
        fi
        printf 'systemd_job,name=%s %s%s\n' "$(property "$unit" Id)" "$fields" "$(nextExecutionGap "$unit")"
      done
    '';
  };
in
{
  imports = [
    inputs.srvos.nixosModules.mixins-telegraf
    ./btrfs.nix
    ./fwupd.nix
    ./monitoring.nix
  ];

  options.qois.telegraf = {
    enable = lib.mkEnableOption "telegraf metrics agent";

    serviceInputs = lib.mkOption {
      # Same type as services.telegraf.extraConfig, so that several modules declaring
      # the same input concatenate rather than overriding each other.
      type = (pkgs.formats.toml { }).type;
      default = { };
      description = ''
        Telegraf inputs contributed by service modules, as opposed to the host-level
        inputs of this module and srvos. Module tests restrict telegraf to these.
      '';
    };

    periodicJobs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "postgresqlBackup.service" ];
      description = ''
        Oneshot systemd services whose last successful exit is monitored.
        Exported as `systemd_job_success` and `systemd_job_last_success_timestamp`, and for
        jobs started by a timer that has fired, `systemd_job_next_execution_gap_seconds`:
        the time between the timer's last and next trigger.
      '';
    };

    periodicJobsInterval = lib.mkOption {
      type = lib.types.str;
      default = "1m";
      description = "Interval at which the status of `periodicJobs` is collected.";
    };
  };

  config = lib.mkMerge [
    { services.telegraf.extraConfig.inputs = cfg.serviceInputs; }

    (lib.mkIf (cfg.periodicJobs != [ ]) {
      qois.telegraf.serviceInputs.exec = [
        {
          commands = [
            "${systemdJobStatus}/bin/systemd-job-status ${
              concatMapStringsSep " " escapeShellArg cfg.periodicJobs
            }"
          ];
          data_format = "influx";
          interval = cfg.periodicJobsInterval;
          timeout = "10s";
        }
      ];
    })

    (lib.mkIf cfg.enable {
      networking.firewall.interfaces."wg-backplane".allowedTCPPorts = [ 9273 ];

      services.telegraf = {
        enable = true;
        extraConfig = {
          agent = {
            quiet = true;
            skip_processors_after_aggregators = true;
          };
          outputs.prometheus_client.expiration_interval = "10m";
          inputs = {
            cpu = [
              {
                percpu = false;
                totalcpu = true;
                collect_cpu_time = false;
              }
            ];
            net = { };
            nginx.urls = lib.mkIf config.services.nginx.statusPage (
              lib.mkForce [
                "http://localhost:${toString config.services.nginx.defaultHTTPListenPort}/nginx_status"
              ]
            );
            systemd_units.details = true;
          };
        };
      };
    })
  ];
}
