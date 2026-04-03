{
  config,
  lib,
  ...
}:

with lib;

let
  cfg = config.qois.jellyfin;
in
{
  options.qois.jellyfin = {
    enable = mkEnableOption "Jellyfin media server for microvm guest";

    domain = mkOption {
      type = types.str;
      default = "media.qo.is";
      description = "Domain name for the Jellyfin instance.";
    };

    dbPasswordFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to PostgreSQL password file (for future use).";
    };

    dbHost = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "PostgreSQL host address (for future use).";
    };

    dbPort = mkOption {
      type = types.port;
      default = 5432;
      description = "PostgreSQL port (for future use).";
    };
  };

  config = mkIf cfg.enable {
    services.jellyfin = {
      enable = true;
      openFirewall = true;
    };
  };
}
