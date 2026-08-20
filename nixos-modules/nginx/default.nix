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
    concatMapStringsSep
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
  options.qois.nginx.behindLoadbalancer = mkEnableOption ''
    that this host is only ever reached over ports 80/443 through one of the
    backplane HAProxy instances (nixos-modules/loadbalancer), which forward
    with send-proxy-v2. When set, nginx requires and trusts the PROXY
    protocol header on its public listener, while a separate loopback
    listener without it keeps local self-calls (e.g. via the per-service
    `networking.hosts."127.0.0.1"` aliases) and telegraf's plain-HTTP
    nginx_status scrape working
  '';

  config.services.nginx = {
    recommendedTlsSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedGzipSettings = true;
    recommendedBrotliSettings = true;
    logError = "stderr warn";
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

    appendHttpConfig = mkIf cfg.behindLoadbalancer (
      concatMapStringsSep "\n" (ip: "set_real_ip_from ${ip};") trustedProxyIps
      + "\nreal_ip_header proxy_protocol;\n"
    );
  };
}
