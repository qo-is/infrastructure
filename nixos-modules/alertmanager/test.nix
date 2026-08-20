{ ... }:
{
  nodes.server =
    { pkgs, lib, ... }:
    {
      qois.prometheus.enable = true;
      qois.alertmanager = {
        enable = true;
        msmtpPasswordFile = pkgs.writeText "msmtp-test-password" "dummy";
      };

      sops.secrets = lib.mkForce { };
    };
}
