{ lib, ... }:
let
  inherit (lib) listToAttrs;
in
{

  qois.services.postgres = {
    net = {
      address = 2; # This is used for network ip's etc. and must be unique
      exposes = {
        postgres = {
          port = 5432;
          scope = "internal";
          protocols = [ "tcp" ];
        };
        postgres-prometheus = {
          port = 9187;
          scope = "internal";
          protocols = [ "http" ];
        };
      };
    };

    persist = {
      "postgres" = {
        tier = "hot";
        mountpoint = "/var/lib/postgres"
      };
      "postgresql-backup" = {
        tier = "cool";
      };
    };


    settings =
      let
        databases = [
          "nextcloud"
          "vaultwarden"
        ];
      in
      {
        inherit databases;

        # Create a user per DB
        users = listToAttrs (name: {
          inherit name;
        }) databases;

      };
  };
}
