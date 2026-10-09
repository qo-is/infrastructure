{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) getExe mkIf readFile;
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
  config = mkIf (config.qois.telegraf.enable && config.services.fwupd.enable) {
    qois.telegraf.periodicJobs = [ "fwupd-refresh.service" ];

    services.telegraf.extraConfig.inputs.exec = [
      {
        commands = [ (getExe fwupdUpdates) ];
        data_format = "influx";
        interval = "5m";
        timeout = "1m";
      }
    ];
  };
}
