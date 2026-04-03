{ ... }:
{
  nodes.server =
    { pkgs, ... }:
    {
      imports = [ ./default.nix ];

      # Write a known password to a file for the module to read
      systemd.tmpfiles.rules = [
        "f /run/test-pg-password 0440 root postgres - testpassword123"
      ];

      qois.postgresql.package = pkgs.postgresql_16;

      qois.microvm-postgres = {
        enable = true;
        passwordFile = "/run/test-pg-password";
        databases = [ "testuser" ];
        users = [
          {
            name = "testuser";
            ensureDBOwnership = true;
          }
        ];
        allowedCIDR = "127.0.0.0/8";
      };

      environment.systemPackages = [ pkgs.postgresql_16 ];
    };
}
