{
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.qois.attic;
in
{

  options.qois.attic = {
    enable = mkEnableOption "Enable attic service";
    domain = mkOption {
      description = "Domain for attic server";
      type = types.str;
      default = "attic.qo.is";
    };
    port = mkOption {
      description = "Server Port";
      type = types.numbers.between 1 65536;
      default = 8080;
    };
  };

  config = mkIf cfg.enable {
    sops.secrets."attic/server_token".restartUnits = [ "atticd.service" ];

    services.atticd = {
      enable = true;

      # Replace with absolute path to your credentials file
      # generate secret with
      # nix run system#openssl rand 64 | base64 -w0
      # ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64="output from openssl"
      environmentFile = config.sops.secrets."attic/server_token".path;

      settings = {
        listen = "127.0.0.1:${toString cfg.port}";
        allowed-hosts = [ cfg.domain ];
        api-endpoint = "https://${cfg.domain}/";

        # Data chunking
        #
        # Warning: If you change any of the values here, it will be
        # difficult to reuse existing chunks for newly-uploaded NARs
        # since the cutpoints will be different. As a result, the
        # deduplication ratio will suffer for a while after the change.
        chunking = {
          # The minimum NAR size to trigger chunking
          #
          # If 0, chunking is disabled entirely for newly-uploaded NARs.
          # If 1, all NARs are chunked.
          nar-size-threshold = 64 * 1024; # 64 KiB

          # The preferred minimum size of a chunk, in bytes
          min-size = 16 * 1024; # 16 KiB

          # The preferred average size of a chunk, in bytes
          avg-size = 64 * 1024; # 64 KiB

          # The preferred maximum size of a chunk, in bytes
          max-size = 256 * 1024; # 256 KiB
        };

        garbage-collection.default-retention-period = "6 months";

        database.url = "postgresql:///atticd?host=/run/postgresql";
      };
    };

    # Note: Attic cache availability is "best effort", so no artifacts are backed up.

    services.postgresql = {
      enable = true;
      ensureDatabases = [ "atticd" ];
      ensureUsers = [
        {
          name = "atticd";
          ensureDBOwnership = true;
        }
      ];
    };

    services.nginx = {
      enable = true;
      clientMaxBodySize = "10G";
      virtualHosts.${cfg.domain} = {
        kTLS = true;
        forceSSL = true;
        enableACME = true;

        locations."/".proxyPass = "http://127.0.0.1:${toString cfg.port}";
      };
    };
  };
}
