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
  inherit (pkgs)
    coreutils
    gawk
    gnused
    writeShellApplication
    ;
  btrfsStats = writeShellApplication {
    name = "btrfs-stats";
    runtimeInputs = [
      coreutils
      gawk
      gnused
    ];
    text = readFile ./btrfs-stats.sh;
  };
in
{
  options.qois.telegraf.btrfsInterval = mkOption {
    type = str;
    default = "1m";
    description = "Interval at which btrfs device and filesystem stats are collected.";
  };

  config = mkIf (cfg.enable && config.boot.supportedFilesystems.btrfs or false) {
    services.telegraf.extraConfig.inputs.exec = [
      {
        commands = [ (getExe btrfsStats) ];
        data_format = "influx";
        interval = cfg.btrfsInterval;
        timeout = "10s";
      }
    ];
  };
}
