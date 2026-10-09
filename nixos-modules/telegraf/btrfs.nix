{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) getExe mkIf readFile;
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
  config = mkIf (config.qois.telegraf.enable && config.boot.supportedFilesystems.btrfs or false) {
    services.telegraf.extraConfig.inputs.exec = [
      {
        commands = [ (getExe btrfsStats) ];
        data_format = "influx";
        interval = "1m";
        timeout = "10s";
      }
    ];
  };
}
