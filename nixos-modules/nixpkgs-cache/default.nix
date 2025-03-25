{
  config,
  lib,
  ...
}:

let
  cfg = config.qois.nixpkgs-cache;
in
with lib;
{
  options.qois.nixpkgs-cache = {
    enable = mkEnableOption ''Enable nixpkgs cache server.'';

    hostname = mkOption {
      type = types.str;
      example = "mycache.myhost.org";
      default = "nixpkgs-cache.qo.is";
      description = "Hostname, under which the cache is served";
    };

    timeout = mkOption {
      type = types.str;
      default = "90d";
      description = "Timespan after which cache entries should be removed.";
    };

    size = mkOption {
      type = types.int;
      default = 50;
      description = "in GB; maximum size of the cache on disk.";
    };

    dnsResolvers = mkOption {
      type = types.listOf types.str;
      example = [ "8.8.8.8" ];
      description = ''
        List of DNS resolvers to use for upstream cache hostname resolution.
        Note: IPv6 is not supported currently.
      '';
    };
  };

  config = mkIf cfg.enable {
    networking.hosts."127.0.0.1" = [ cfg.hostname ];
    services.nginx = {
      enable = true;
      resolver.ipv6 = false; # TODO(6): Support IPv6
      resolver.addresses = cfg.dnsResolvers;

      proxyCachePath.nixpkgs-cache = {
        enable = true;
        keysZoneName = "nixpkgs_cache";
        maxSize = "${builtins.toString cfg.size}G";
        keysZoneSize = "${builtins.toString (cfg.size * 3)}M"; # Assumes 3MB keys storage per GB
        inactive = cfg.timeout;
      };

      virtualHosts.${cfg.hostname} = {
        kTLS = true;
        forceSSL = true;
        enableACME = true;

        locations."/" = {
          proxyPass = "https://cache.nixos.org";
          recommendedProxySettings = false;
          extraConfig = ''
            proxy_cache nixpkgs_cache;
            proxy_cache_valid ${cfg.timeout};
            proxy_cache_use_stale error timeout invalid_header updating http_500 http_502 http_504 http_403 http_404 http_429;
            proxy_ignore_headers X-Accel-Expires Expires Cache-Control Set-Cookie; # Files are immutable so just keep them
            proxy_cache_lock on;
            proxy_ssl_server_name on;
            proxy_ssl_session_reuse off;
            proxy_ssl_verify on;
            proxy_ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;
            proxy_set_header Host cache.nixos.org;
          '';
        };
      };
    };
  };
}
