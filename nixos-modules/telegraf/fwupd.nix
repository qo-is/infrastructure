{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    getExe
    mkIf
    mkOption
    readFile
    ;
  inherit (lib.types) str;
  cfg = config.qois.telegraf;
  inherit (pkgs) jq writeShellApplication;
  fwupdUpdates = writeShellApplication {
    name = "fwupd-updates";
    runtimeInputs = [
      config.services.fwupd.package
      jq
    ];
    text = readFile ./fwupd-updates.sh;
  };
in
{
  options.qois.telegraf.fwupdInterval = mkOption {
    type = str;
    default = "5m";
    description = "Interval at which pending fwupd firmware updates are collected.";
  };

  config = mkIf (cfg.enable && config.services.fwupd.enable) {
    qois.telegraf.periodicJobs = [ "fwupd-refresh.service" ];

    services.telegraf.extraConfig.inputs.exec = [
      {
        commands = [ (getExe fwupdUpdates) ];
        data_format = "influx";
        interval = cfg.fwupdInterval;
        timeout = "1m";
      }
    ];
  };
}
