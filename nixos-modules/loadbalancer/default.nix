{
  config,
  pkgs,
  lib,
  ...
}:

with lib;
let
  # We assume that all static pages are hosted on lindberg-webapps
  staticPages = pipe config.qois.static-page.pages [
    (mapAttrsToList (_name: { domain, domainAliases, ... }: [ domain ] ++ domainAliases))
    flatten
    (map (name: {
      inherit name;
      value = "lindberg-webapps";
    }))
    listToAttrs
  ];
  defaultDomains = staticPages // {
    "cloud.qo.is" = "lindberg-nextcloud";

    "build.qo.is" = "lindberg-build";
    "gitlab-runner.qo.is" = "lindberg-build";
    "nixpkgs-cache.qo.is" = "lindberg-build";
    "attic.qo.is" = "lindberg-build";

    "vault.qo.is" = "lindberg-webapps";
    "git.qo.is" = "lindberg-webapps";

    "kokus.raphael.li" = "lindberg-rzimmermann";
    "auth.raphael.li" = "lindberg-rzimmermann";
    "toolia.raphael.li" = "lindberg-rzimmermann";
    "ha.raphael.li" = "lindberg-rzimmermann";
    "www.raphael.li" = "lindberg-rzimmermann";

    "vpn.qo.is" = "cyprianspitz-headscale";
    "www.resourcee.fh2.ch" = "workstations-9001";
  };
  getBackplaneIp = hostname: config.qois.meta.network.virtual.backplane.hosts.${hostname}.v4.ip;
  defaultHostmap =
    lib.pipe
      [
        "lindberg-nextcloud"
        "lindberg-build"
        "lindberg-webapps"
      ]
      [
        (map (name: {
          inherit name;
          value = getBackplaneIp name;
        }))
        lib.listToAttrs
      ];
  defaultExtraConfig =
    let
      headscalePort = toString 46084;
      rzimmermannIp = "10.247.0.113";
    in
    ''
      # lindberg-rzimmermann (uses send-proxy-v2)
      backend lindberg-rzimmermann-https
        mode tcp
        server s1 ${rzimmermannIp}:443 send-proxy-v2

      backend lindberg-rzimmermann-http
        mode http
        server s1 ${rzimmermannIp}:80

      # cyprianspitz headscale
      backend cyprianspitz-headscale-http
        mode http
        server s1 ${getBackplaneIp "cyprianspitz"}:${headscalePort}

      backend cyprianspitz-headscale-https
        mode tcp
        server s1 ${getBackplaneIp "cyprianspitz"}:${headscalePort}

      # Winder Study Project (tmp)
      backend workstations-9001-http
        mode http
        server s1 10.247.0.156:9001
    '';
  cfg = config.qois.loadbalancer;
in
{

  options.qois.loadbalancer = {
    enable = mkEnableOption "Enable services http+s loadbalancing";

    domains = mkOption {
      description = "Domain to hostname mappings";
      type = with lib.types; attrsOf str;
      default = defaultDomains;
    };

    hostmap = mkOption {
      description = "Hostname to IP mappings for TLS-TCP and http forwarding";
      type = with lib.types; attrsOf str;
      default = defaultHostmap;
    };

    extraConfig = mkOption {
      description = "Additional haproxy mapping configs. Amended to services.haproxy.config. Make sure indentations are correct.";
      type = types.nullOr types.lines;
      default = defaultExtraConfig;
    };

  };

  config =
    with lib;
    mkIf cfg.enable {

      networking.firewall.allowedTCPPorts = [
        80
        443
      ];

      services.haproxy =
        let
          domainMappingFile = pipe cfg.domains [
            (mapAttrsToList (host: backend: "${host} ${backend}"))
            concatLines
            (pkgs.writeText "haproxy_backend_map")
          ];
          genHttpBackend = hostName: ip: ''

            # Mapping for ${hostName}
            backend ${hostName}-https
              mode tcp
              server s1 ${ip}:443

            backend ${hostName}-http
              mode http
              server s1 ${ip}:80
          '';
          httpBackends = pipe cfg.hostmap [
            (mapAttrsToList genHttpBackend)
            concatLines
          ];
        in
        {
          enable = true;
          config = ''
            defaults
              mode http
              retries 3
              maxconn 2000
              timeout connect 5000
              timeout client 50000
              timeout server 50000

            frontend http
              mode http
              bind *:80
              use_backend %[req.hdr(host),lower,map(${domainMappingFile})]-http

            frontend https
              bind *:443
              mode tcp
              tcp-request inspect-delay 5s
              tcp-request content accept if { req_ssl_hello_type 1 }

              use_backend %[req.ssl_sni,lower,map(${domainMappingFile})]-https

            ## Generated Backends:
            ${httpBackends}

            ## extraConfig
            ${cfg.extraConfig}
          '';
        };
    };
}
