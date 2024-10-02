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
  defaultDnsRecords = mapAttrs (
    name: value: mkIf (cfgLoadbalancer.hostmap ? ${value}) cfgLoadbalancer.hostmap.${value}
  ) cfgLoadbalancer.domains;
in
{

  options.qois.vpn-server = {
    enable = mkEnableOption "Enable vpn server services";
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

    qois.backup-client.includePaths =
      with config.services.headscale.settings;
      (
        [
          db_path
          private_key_path
          noise.private_key_path
        ]
        ++ derp.paths
      );

    networking.firewall.checkReversePath = "loose";
    networking.firewall.allowedUDPPorts = [
      41641
    ];
    services.headscale =
      let
        vnet = config.qois.meta.network.virtual;
        vpnNet = vnet.vpn;
        vpnNetPrefix = "${vpnNet.v4.id}/${builtins.toString vpnNet.v4.prefixLength}";
        backplaneNetPrefix = "${vnet.backplane.v4.id}/${builtins.toString vnet.backplane.v4.prefixLength}";
      in
      {
        enable = true;
        address = vnet.backplane.hosts.cyprianspitz.v4.ip;
        port = 46084;
        settings = {
          server_url = "https://${vpnNet.domain}:443";

          tls_letsencrypt_challenge_type = "TLS-ALPN-01";
          tls_letsencrypt_hostname = vpnNet.domain;

          dns_config = {
            nameservers = [ vnet.backplane.hosts.calanda.v4.ip ];
            domains = [
              vpnNet.domain
              vnet.backplane.domain
            ];
            magic_dns = true;
            base_domain = vpnNet.domain;
            extra_records = pipe cfg.dnsRecords [
              attrsToList
              (map (val: val // { type = "A"; }))
            ];
          };

          ip_prefixes = [ vpnNetPrefix ];

          acl_policy_path = pkgs.writeTextFile {
            name = "acls";
            text = builtins.toJSON {
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
          };
        };
      };
  });
}
