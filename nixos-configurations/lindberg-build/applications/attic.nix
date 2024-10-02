{ config, pkgs, ... }:

let
  atticPort = 8080;
  atticHostname = "attic.qo.is";
in

{

  services.atticd = {
    enable = true;

    # Replace with absolute path to your credentials file
    # generate secret with
    # nix run system#openssl rand 64 | base64 -w0
    # ATTIC_SERVER_TOKEN_HS256_SECRET_BASE64="output from openssl"
    credentialsFile = config.sops.secrets."attic/server_token".path;

    settings = {
      listen = "127.0.0.1:${builtins.toString atticPort}";
      allowed-hosts = [ "attic.qo.is" ];
      api-endpoint = "https://attic.qo.is/";

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

      database.url = "postgresql:///atticd?host=/run/postgresql";
    };
  };

  imports = [ ../../../defaults/webserver ];

  qois.postgresql.enable = true;
  # Note: Attic cache availability is "best effort", so no artifacts are backed up.

  services.postgresql = {
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
    clientMaxBodySize = "1g";
    virtualHosts.${atticHostname} = {
      kTLS = true;
      forceSSL = true;
      enableACME = true;

      locations."/".proxyPass = "http://127.0.0.1:${builtins.toString atticPort}";
    };
  };
}
