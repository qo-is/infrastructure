{
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.qois.vpn-exit-node;
in
{

  options.qois.vpn-exit-node = {
    enable = mkEnableOption "vpn exit node";
    domain = mkOption {
      description = "Domain for the VPN admin server";
      type = types.str;
      default = "vpn.qo.is";
    };
  };

  config = mkIf cfg.enable {

    qois.backup-client.includePaths = [ "/var/lib/tailscale" ];

    sops.secrets."tailscale/key".restartUnits = [ "tailscaled.service" ];

    services.tailscale = {
      enable = true;
      openFirewall = true;
      useRoutingFeatures = "server";
      authKeyFile = config.sops.secrets."tailscale/key".path;
      extraUpFlags =
        let
          backplaneRoute =
            with config.qois.meta.network.virtual.backplane.v4;
            "${id}/${builtins.toString prefixLength}";
        in
        [
          "--timeout 60s"
          "--accept-dns=false"
          "--accept-routes=false"
          "--login-server=https://${cfg.domain}"
          "--advertise-exit-node"
          "--advertise-routes=${backplaneRoute}"
          "--advertise-tags=tag:srv"
        ];
    };
  };
}
