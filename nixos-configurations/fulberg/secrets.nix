{ ... }:
{
  sops.secrets = {
    "tailscale/key" = {
      restartUnits = [ "tailscale.service" ];
    };
  };
}
