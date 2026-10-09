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
    ./btrfs.nix
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
