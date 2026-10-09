{
  config,
  lib,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkIf
    optionals
    concatStringsSep
    ;
  inherit (config.qois.meta.network.virtual) backplane;
  loadbalancerHosts = [
    "lindberg"
    "cyprianspitz"
  ];
  trustedProxyIps = map (name: backplane.hosts.${name}.v4.ip) loadbalancerHosts;
  cfg = config.qois.nginx;
in
{
  options.qois.nginx.behindLoadbalancer = mkEnableOption "requiring and trusting the PROXY protocol header on nginx's public listener";

  config.services.nginx = {
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedBrotliSettings = true;
    logError = "stderr error";
    proxyResolveWhileRunning = true;
    statusPage = config.services.nginx.enable;

    defaultListen = mkIf cfg.behindLoadbalancer (
      [
        {
          addr = "0.0.0.0";
          proxyProtocol = true;
        }
        { addr = "127.0.0.1"; }
      ]
      ++ optionals config.networking.enableIPv6 [
        {
          addr = "[::0]";
          proxyProtocol = true;
        }
        { addr = "[::1]"; }
      ]
    );

    appendHttpConfig = concatStringsSep "\n" (
      [ "log_not_found off;" ]
      ++ optionals cfg.behindLoadbalancer (
        map (ip: "set_real_ip_from ${ip};") trustedProxyIps ++ [ "real_ip_header proxy_protocol;" ]
      )
    );
  };
}
