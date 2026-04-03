{ ... }:
let
  # Guest module definitions (imported so qois.* options exist inside the guest)
  guestModulePaths = {
    microvm-postgres = ../../../nixos-modules/microvm-postgres/default.nix;
    jellyfin = ../../../nixos-modules/jellyfin/default.nix;
  };
in
{
  qois.microvm = {
    enable = true;
    netName = "lindberg-microvms";

    secrets.jellyfin-db-password = { }; # defaults: pwgen -s 32, fileName = "password"

    services.postgres = {
      enable = true;
      index = 1; # → 10.249.0.2
      vcpus = 2;
      mem = 4096;
      secrets = [ "jellyfin-db-password" ];
      openHostFirewallTCP = [ 5432 ];
      guestModules = [
        guestModulePaths.microvm-postgres
        (
          { ... }:
          {
            qois.microvm-postgres = {
              enable = true;
              databases = [ "jellyfin" ];
              users = [
                {
                  name = "jellyfin";
                  ensureDBOwnership = true;
                }
              ];
              passwordFile = "/run/microvm-secrets/jellyfin-db-password/password";
            };
          }
        )
      ];
    };

    services.jellyfin = {
      enable = true;
      index = 2; # → 10.249.0.3
      vcpus = 4;
      mem = 4096;
      secrets = [ "jellyfin-db-password" ];
      dependsOn = [ "postgres" ];
      shares = [
        {
          tag = "media";
          source = "/mnt/data/media";
          mountPoint = "/media";
        }
      ];
      guestModules = [
        guestModulePaths.jellyfin
        (
          { ... }:
          {
            qois.jellyfin = {
              enable = true;
              dbPasswordFile = "/run/microvm-secrets/jellyfin-db-password/password";
              dbHost = "10.249.0.2"; # postgres VM (base + index + 1 = .0 + 1 + 1)
            };
          }
        )
      ];
    };
  };
}
