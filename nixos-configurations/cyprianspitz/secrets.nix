{ ... }:
{
  sops.secrets = {
    "system/hdd" = { };
    "system/initrd-ssh-key" = { };
    "tailscale/key" = {
      restartUnits = [ "tailscaled.service" ];
    };
  };
}
