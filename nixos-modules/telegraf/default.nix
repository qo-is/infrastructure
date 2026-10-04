{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) concatMapStringsSep escapeShellArg;
  inherit (pkgs) gawk systemd writeShellApplication;
  cfg = config.qois.telegraf;

  systemdJobStatus = writeShellApplication {
    name = "systemd-job-status";
    runtimeInputs = [
      gawk
      systemd
    ];
    text = ''
      systemctl show --timestamp=unix --property=Id,Result,ExecMainExitTimestamp "$@" | awk -F= '
        function flush() {
          if (id == "") return
          if (result == "success" && ts != "")
            printf "systemd_job,name=%s success=1i,last_success_timestamp=%si\n", id, ts
          else
            printf "systemd_job,name=%s success=0i\n", id
          id = result = ts = ""
        }
        $0 == "" { flush(); next }
        $1 == "Id" { id = $2 }
        $1 == "Result" { result = $2 }
        $1 == "ExecMainExitTimestamp" { ts = substr($2, 2) }
        END { flush() }
      '
    '';
  };
in
{
  imports = [
    inputs.srvos.nixosModules.mixins-telegraf
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
        Oneshot systemd services that must exit successfully at least every 30h.
        Exported as `systemd_job_success` and `systemd_job_last_success_timestamp`.
      '';
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
          interval = "1m";
          timeout = "10s";
        }
      ];
    })

    {
      # systemd forgets exit timestamps on reboot, max_over_time keeps the last success visible.
      srvos.prometheus.ruleGroups.qoisPeriodicJobs.alertRules.PeriodicJobNotSucceeded = {
        expr = "systemd_job_success unless on(host, name) (time() - max_over_time(systemd_job_last_success_timestamp[30h]) < 30 * 3600)";
        for = "1h";
        annotations.description = "{{$labels.host}}: {{$labels.name}} has not exited successfully in the last 30h";
      };
    }

    (lib.mkIf cfg.enable {
      networking.firewall.interfaces."wg-backplane".allowedTCPPorts = [ 9273 ];

      services.telegraf = {
        enable = true;
        extraConfig = {
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
