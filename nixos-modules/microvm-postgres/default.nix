{
  config,
  pkgs,
  lib,
  ...
}:

with lib;

let
  cfg = config.qois.microvm-postgres;
in
{
  options.qois.microvm-postgres = {
    enable = mkEnableOption "PostgreSQL for microvm guest";

    package = mkPackageOption pkgs "postgresql_16" { };

    passwordFile = mkOption {
      type = types.str;
      description = "Path to the file containing the superuser password.";
    };

    databases = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Databases to create.";
    };

    users = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "PostgreSQL user name.";
            };
            ensureDBOwnership = mkOption {
              type = types.bool;
              default = false;
              description = "Whether the user should own a database with the same name.";
            };
          };
        }
      );
      default = [ ];
      description = "Users to create.";
    };

    listenAddresses = mkOption {
      type = types.str;
      default = "*";
      description = "Addresses PostgreSQL listens on.";
    };

    allowedCIDR = mkOption {
      type = types.str;
      default = "10.249.0.0/24";
      description = "CIDR range allowed for password-based connections.";
    };
  };

  config = mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      package = cfg.package;
      enableTCPIP = true;

      ensureDatabases = cfg.databases;
      ensureUsers = map (u: {
        inherit (u) name ensureDBOwnership;
      }) cfg.users;

      authentication = ''
        # Allow password auth from microvm network
        host all all ${cfg.allowedCIDR} md5
      '';

      settings = {
        listen_addresses = cfg.listenAddresses;
      };

      initialScript = pkgs.writeText "pg-init.sql" ''
        ALTER USER postgres WITH PASSWORD '${builtins.replaceStrings [ "'" ] [ "''" ] "PLACEHOLDER"}';
      '';
    };

    # Set user passwords from the secret file after postgresql starts
    systemd.services.postgresql-set-passwords = {
      description = "Set PostgreSQL user passwords from secrets";
      after = [ "postgresql.service" ];
      wantedBy = [ "multi-user.target" ];
      requires = [ "postgresql.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
      };
      script =
        let
          userStatements = concatMapStringsSep "\n" (
            u:
            ''${config.services.postgresql.package}/bin/psql -c "ALTER USER ${u.name} WITH PASSWORD '$(cat ${cfg.passwordFile})';"''
          ) cfg.users;
        in
        ''
          # Set postgres superuser password
          ${config.services.postgresql.package}/bin/psql -c "ALTER USER postgres WITH PASSWORD '$(cat ${cfg.passwordFile})';"
          # Set application user passwords
          ${userStatements}
        '';
    };

    networking.firewall.allowedTCPPorts = [ 5432 ];
  };
}
