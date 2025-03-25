{ pkgs, ... }:
{
  virtualisation.libvirtd = {
    enable = true;
    onShutdown = "shutdown";
  };
  environment.systemPackages = [ pkgs.virtiofsd ];
}
