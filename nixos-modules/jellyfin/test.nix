{ ... }:
{
  nodes.server =
    { pkgs, ... }:
    {
      imports = [ ./default.nix ];

      qois.jellyfin.enable = true;

      virtualisation.diskSize = 4096;

      environment.systemPackages = [ pkgs.curl ];
    };
}
