{
  config,
  lib,
  ...
}:

with lib;
with types;

let
  cfg = config.qois.meta.network;
  mkStr =
    description:
    (mkOption {
      type = str;
      inherit description;
    });

  mkNetworkIdOpts =
    v:
    assert v == 4 || v == 6;
    submodule {
      options = {
        id = mkOption {
          type = types.str;
          description = ''
            IPv${toString v} ID
          '';
        };

        prefixLength = mkOption {
          type = types.addCheck types.int (n: n >= 0 && n <= (if v == 4 then 32 else 128));
          description = ''
            Subnet mask of the ip, specified as the number of
            bits in the prefix (<literal>${if v == 4 then "24" else "64"}</literal>).
          '';
        };

        gateway = mkOption {
          default = null;
          type = nullOr str;
          description = ''
            Upstream Gateway IP
          '';
        };

        nameservers = mkOption {
          default = null;
          type = nullOr (listOf str);
          description = "Nameserver IP";
        };
      };
    };
  mkFqdn =
    host: domain:
    mkOption {
      type = str;
      default = "${config.qois.meta.hosts.${host}.hostName}.${domain}";
      description = ''
        The fully qualified domain name (FYDN) of this host inside of this specific
        network. Defaults to the host attribute key and net domain.
      '';
    };
in
{
  options.qois.meta.network.physical = mkOption {
    description = "Physical network configuration";
    type = attrsOf (
      submodule (
        { name, ... }:
        let
          networkName = name;
        in
        {
          options = {
            v4 = mkOption { type = (mkNetworkIdOpts 4); };
            v6 = mkOption { type = nullOr (mkNetworkIdOpts 6); };
            domain = mkStr "Network DNS Domain suffix";
            hosts = mkOption {
              type = attrsOf (
                submodule (
                  { name, ... }:
                  let
                    host = name;
                  in
                  {
                    options = {
                      v4 = mkOption { type = submodule { options.ip = mkStr "The V4 host IP address"; }; };
                      v6 = mkOption {
                        default = null;
                        type = nullOr (submodule {
                          options.ip = mkStr "The V6 host IP address";
                        });
                      };
                      fqdn = mkFqdn host cfg.physical.${networkName}.domain;
                    };
                  }
                )
              );
            };
          };
        }
      )
    );
    default = { };
  };
  options.qois.meta.network.virtual = mkOption {
    description = "Virtual network configuration";
    type = types.attrsOf (
      types.submodule (
        { name, ... }:
        let
          networkName = name;
        in
        {
          options = {
            v4 = mkOption { type = (mkNetworkIdOpts 4); };
            v6 = mkOption {
              default = null;
              type = nullOr (mkNetworkIdOpts 6);
            };
            domain = mkStr "Network DNS Domain suffix";
            hosts = mkOption {
              type = attrsOf (
                submodule (
                  { name, ... }:
                  let
                    host = name;
                  in
                  {
                    options = {
                      v4 = mkOption { type = submodule { options.ip = mkStr "The V4 host IP address"; }; };
                      v6 = mkOption {
                        default = null;
                        type = nullOr (submodule {
                          options.ip = mkStr "The V6 host IP address";
                        });
                      };

                      # Taken from https://github.com/NixOS/nixpkgs/blob/nixos-21.11/nixos/modules/services/networking/wireguard.nix:
                      publicKey = mkOption {
                        example = "xTIBA5rboUvnH4htodjb6e697QjLERt1NAB4mZqp8Dg=";
                        type = str;
                        description = "The base64 public key of the peer.";
                      };
                      persistentKeepalive = mkOption {
                        default = null;
                        type = nullOr int;
                        example = 25;
                        description = ''
                          This is optional and is by default off, because most
                          users will not need it. It represents, in seconds, between 1 and 65535
                          inclusive, how often to send an authenticated empty packet to the peer,
                          for the purpose of keeping a stateful firewall or NAT mapping valid
                          persistently. For example, if the interface very rarely sends traffic,
                          but it might at anytime receive traffic from a peer, and it is behind
                          NAT, the interface might benefit from having a persistent keepalive
                          interval of 25 seconds; however, most users will not need this.'';
                      };

                      # Endpoint Configuration:
                      endpoint = mkOption {
                        description = ''
                          FQDN and port of this vpn-endpoint. This option indicates this host is a VPN
                          server.
                        '';
                        default = null;
                        type = nullOr (submodule {
                          options = {
                            fqdn = mkFqdn host cfg.virtual.${networkName}.domain;
                            port = mkOption {
                              type = types.addCheck types.int (n: n > 0 && n < 65536);
                              description = ''
                                The port on which the wireguard endpoint receives packages.
                              '';
                            };
                          };
                        });
                      };
                    };
                  }
                )
              );
            };
          };
        }
      )
    );
    default = { };
  };
  config = {
    programs.ssh.knownHosts =
      let
        # hostname -> single network cfg attr -> ["known host's names"]
        getHostNamesFromNetwork =
          hostname: network:
          if network.hosts ? ${hostname} && network.hosts.${hostname} != null then
            let
              hostCfg = network.hosts.${hostname};
            in
            [
              "${hostname}.${network.domain}"
              hostCfg.v4.ip
            ]
            ++ (if hostCfg.v6 != null then [ hostCfg.v6.ip ] else [ ])
          else
            [ ];

        # hostname -> attr of network defs -> ["known host's names"]
        getHostNamesForNetworks =
          hostname: networks: lib.flatten (map (getHostNamesFromNetwork hostname) (lib.attrValues networks));

        # hostname -> ["known host's names"]
        getHostNames =
          hostname:
          (getHostNamesForNetworks hostname cfg.virtual) ++ (getHostNamesForNetworks hostname cfg.physical);

        hostsWithPublicKey = lib.filterAttrs (
          _hostName: hostConfig: hostConfig.sshKey != null
        ) config.qois.meta.hosts;
      in
      mapAttrs (name: _hostCfg: { extraHostNames = getHostNames name; }) hostsWithPublicKey;

  };
}
