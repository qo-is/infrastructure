{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.qois.vpn-server;
  cfgLoadbalancer = config.qois.loadbalancer;
  defaultDnsRecords =
    (mapAttrs (
      _name: value: mkIf (cfgLoadbalancer.hostmap ? ${value}) cfgLoadbalancer.hostmap.${value}
    ) cfgLoadbalancer.domains)
    // {
      "vpn.qo.is" = config.services.headscale.address;
    };
in
{

  options.qois.vpn-server = {
    enable = mkEnableOption "Enable vpn server services";
    domain = mkOption {
      description = "Domain for the VPN admin server";
      type = types.str;
      default = "vpn.qo.is";
    };
    dnsRecords = mkOption {
      description = "DNS records to add to Hosts";
      type = with types; attrsOf str;
      default = defaultDnsRecords;
    };
    wheelUsers = mkOption {
      description = "Usernames that can change configurations";
      type = with types; listOf str;
      default = [ ];
    };
  };

  config = mkIf cfg.enable ({

    environment.systemPackages = [ pkgs.headscale ];

    # We bind to the backplane vpn IP, so wait for the wireguard net to be available
    systemd.services.headscale.after = [ "wireguard-wg-backplane.service" ];

    qois.backup-client.includePaths =
      with config.services.headscale.settings;
      (
        [
          database.sqlite.path
          #derp.server.private_key_path # Currently not used
          noise.private_key_path
        ]
        ++ derp.paths
      );

    networking.firewall.checkReversePath = "loose";
    networking.firewall.allowedTCPPorts = [ config.services.headscale.port ];
    networking.firewall.allowedUDPPorts = [
      41641
    ];
    services.headscale =
      let
        vnet = config.qois.meta.network.virtual;
        vpnNet = vnet.vpn;
        vpnNetPrefix = "${vpnNet.v4.id}/${toString vpnNet.v4.prefixLength}";
        backplaneNetPrefix = "${vnet.backplane.v4.id}/${builtins.toString vnet.backplane.v4.prefixLength}";
      in
      {
        enable = true;
        address = vnet.backplane.hosts.cyprianspitz.v4.ip;
        port = 46084;
        settings = {
          server_url = "https://${cfg.domain}:443";

          tls_letsencrypt_challenge_type = "TLS-ALPN-01";
          tls_letsencrypt_hostname = vpnNet.domain;

          dns = {
            base_domain = vpnNet.domain;
            magic_dns = true;
            nameservers.global = [ "127.0.0.1" ];
            search_domains = [
              # First is base_domain by default with magic_dns
              vnet.backplane.domain
            ];
            extra_records = pipe cfg.dnsRecords [
              attrsToList
              (map (val: val // { type = "A"; }))
            ];
          };

          ip_prefixes = [ vpnNetPrefix ];

          policy =
            let
              # Note: headscale has limited acl support currently. This might change in the future.
              aclPolicy = {
                hosts = {
                  "clients" = vpnNetPrefix;
                };
                groups = {
                  "group:wheel" = cfg.wheelUsers;
                };
                tagOwners = {
                  "tag:srv" = [ "srv" ]; # srv tag ist owned by srv user
                };
                autoApprovers = {
                  exitNode = [
                    "tag:srv"
                    "group:wheel"
                  ];
                  routes = {
                    ${backplaneNetPrefix} = [ "tag:srv" ];
                  };
                };

                acls = [
                  # Allow all communication from and to srv tagged hosts
                  {
                    action = "accept";
                    src = [
                      "tag:srv"
                      "srv"
                    ];
                    dst = [ "*:*" ];
                  }
                  {
                    action = "accept";
                    src = [ "*" ];
                    dst = [
                      "tag:srv:*"
                      "srv:*"
                    ];
                  }

                  # Allow access to all connected hosts for wheels
                  {
                    action = "accept";
                    src = [ "group:wheel" ];
                    dst = [ "*:*" ];
                  }
                ];
              };
            in
            {
              mode = "file";
              path = pkgs.writeTextFile {
                name = "acls";
                text = builtins.toJSON aclPolicy;
              };
            };
        };
      };
  });
}
